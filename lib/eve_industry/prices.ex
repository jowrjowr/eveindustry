defmodule EveIndustry.Prices do
  require Logger

  def fetch(type_id) do
    %{
      adjusted_price: Cachex.get!(:adjusted_price, type_id),
      min_sell_price: Cachex.get!(:min_sell_price, type_id),
      max_buy_price: Cachex.get!(:max_buy_price, type_id)
    }
  end

  def adjusted_price(type_id) do
    case Cachex.get!(:adjusted_price, type_id) do
      nil -> 0.0
      price -> price
    end
  end

  def sell_price(type_id) do
    case Cachex.get!(:min_sell_price, type_id) do
      nil -> 0.0
      price -> price
    end
  end

  def buy_price(type_id) do
    case Cachex.get!(:max_buy_price, type_id) do
      nil -> 0.0
      price -> price
    end
  end

  def process_cost_indices() do
    # just shove the blob into ETS
    esi_url = "https://esi.evetech.net/latest/industry/systems"

    req =
      Req.new(
        base_url: esi_url,
        retry: :safe_transient,
        decode_json: [keys: :atoms]
      )

    {:ok, response} = Req.get(req)

    for %{solar_system_id: solar_system_id, cost_indices: cost_indices} <- response.body do
      cost_indices =
        for %{activity: activity, cost_index: cost_index} <- cost_indices,
            into: %{},
            do: {activity, cost_index}

      Cachex.put(:manufacturing_cost_index, solar_system_id, cost_indices["manufacturing"])
      Cachex.put(:reaction_cost_index, solar_system_id, cost_indices["reaction"])
    end

    :ok
  end

  def process_adjusted_prices() do
    # ccp baseprice

    esi_url = "https://esi.evetech.net/latest/markets/prices/"

    req =
      Req.new(
        base_url: esi_url,
        retry: :safe_transient
      )

    Logger.debug("Fetching market")

    {:ok, response} = Req.get(req)

    total_items = length(response.body)
    Logger.debug("Total items in market: #{total_items}")

    for item <- response.body do
      Cachex.put(:adjusted_price, item[:type_id], item[:adjusted_price])
    end

    :ok
  end

  def process_esi_prices(region) do
    data = fetch_market_prices(region)

    amount_of_data = length(data)
    Logger.debug("ESI market records in region #{region}: #{amount_of_data}")

    type_ids =
      data
      |> Enum.reduce([], fn item, acc -> [item[:type_id]] ++ acc end)
      |> Enum.uniq()

    distinct_type_ids = length(type_ids)

    Logger.debug("ESI market distinct types on market in region #{region}: #{distinct_type_ids}")

    # do a little pre-processing to shave off data

    order_key_filter = [
      :duration,
      :issued,
      :location_id,
      :min_volume,
      :order_id,
      :system_id,
      :volume_total
    ]

    data =
      data
      |> Enum.reduce([], fn item, acc -> [Map.drop(item, order_key_filter)] ++ acc end)

    start_time = System.monotonic_time()

    prices =
      data
      |> Enum.group_by(&grab_typeid/1)
      |> Enum.map(fn {type_id, type_data} -> {type_id, calculate_price(type_id, type_data)} end)
      |> Map.new()

    price_time = System.convert_time_unit(System.monotonic_time() - start_time, :native, :millisecond)

    Logger.debug("price calculation time: #{price_time}")

    # take all of this and shove it into ETS

    for type_id <- type_ids do
      data = prices[type_id]

      Cachex.put(:min_sell_price, type_id, data[:min_sell_price])
      Cachex.put(:max_buy_price, type_id, data[:max_buy_price])
    end

    :ok
  end

  defp grab_typeid(%{type_id: type_id}), do: type_id

  def calculate_price(type_id, data) do
    # data = Enum.filter(data, fn item -> item[:type_id] == type_id end)

    # example of ESI data processed:
    #
    # %{
    #   duration: 90,
    #   is_buy_order: false,
    #   issued: "2021-01-26T15:33:26Z",
    #   location_id: 60012898,
    #   min_volume: 1,
    #   order_id: 5908376267,
    #   price: 1003.0,
    #   range: "region",
    #   system_id: 30001041,
    #   type_id: 27435,
    #   volume_remain: 10,
    #   volume_total: 1410
    # }

    # the lengths of these lists is the same so i can split the work

    sell_prices =
      data
      |> Enum.filter(fn item -> item[:is_buy_order] == false end)
      |> Enum.reduce([], fn item, acc -> [item[:price]] ++ acc end)
      |> Enum.sort(&(&1 <= &2))

    sell_price =
      case sell_prices do
        [] -> nil
        _ -> hd(sell_prices)
      end

    buy_prices =
      data
      |> Enum.filter(fn item -> item[:is_buy_order] == true end)
      |> Enum.reduce([], fn item, acc -> [item[:price]] ++ acc end)
      |> Enum.sort(&(&1 >= &2))

    buy_price =
      case buy_prices do
        [] -> nil
        _ -> hd(buy_prices)
      end

    %{
      type_id: type_id,
      min_sell_price: sell_price,
      max_buy_price: buy_price
    }
  end

  def fetch_market_prices(region \\ 10_000_002) do
    # fetch the raw price market data from ESI directly
    # can take awhile at hundreds of pages

    esi_url = "https://esi.evetech.net/latest/markets/#{region}/orders/"

    req =
      Req.new(
        base_url: esi_url,
        retry: :safe_transient,
        decode_json: [keys: :atoms]
      )

    Logger.debug("Fetching market for region #{region}")

    {:ok, response} = fetch_market_page_for_region(region, 1)

    total_pages =
      response.headers
      |> Map.get("x-pages")
      |> hd()
      |> String.to_integer()

    Logger.debug("Total ESI market pages in region #{region}: #{total_pages}")
    first_page = response.body

    stream =
      Task.async_stream(
        2..total_pages,
        fn page ->
          {:ok, response} = fetch_market_page_for_region(region, page)
          response.body
        end,
        max_concurrency: 50
      )

    rest_of_data =
      stream
      |> Enum.reduce([], fn {:ok, data}, acc -> acc ++ data end)

    first_page ++ rest_of_data
  end

  defp fetch_market_page_for_region(region, page) do
    Logger.debug("Fetching ESI market page #{page}")
    esi_url = "https://esi.evetech.net/latest/markets/#{region}/orders/"

    req =
      Req.new(
        base_url: esi_url,
        retry: :safe_transient,
        decode_json: [keys: :atoms],
        params: [page: page]
      )

    Req.get(req)
  end
end
