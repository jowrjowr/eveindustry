defmodule EveIndustry.Prices do
  require Logger

  def fetch(type_id) do
    %{
      adjusted_price: Cachex.get!(:adjusted_price, type_id),
      min_sell_price: Cachex.get!(:min_sell_price, type_id),
      max_buy_price: Cachex.get!(:max_buy_price, type_id)
    }
  end

  def process_cost_indices() do
    # just shove the blob into ETS
    esi_url = "https://esi.evetech.net/latest/industry/systems"

    {:ok, response} = Mojito.request(method: :get, url: esi_url, opts: [timeout: 50000])

    result = Jason.decode!(response.body, keys: :atoms)

    for %{solar_system_id: solar_system_id, cost_indices: cost_indices} <- result do
      cost_indices =
        for %{activity: activity, cost_index: cost_index} <- cost_indices, into: %{}, do: {activity, cost_index}

      Cachex.put(:manufacturing_cost_index, solar_system_id, cost_indices["manufacturing"])
      Cachex.put(:reaction_cost_index, solar_system_id, cost_indices["reaction"])
    end

    :ok

  end
  def process_adjusted_prices() do
    # ccp baseprice

    esi_url = "https://esi.evetech.net/latest/markets/prices/"
    {:ok, response} = Mojito.request(method: :get, url: esi_url)

    result = Jason.decode!(response.body, keys: :atoms)

    for item <- result do
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
      |> Enum.reduce([], fn item, acc -> [ item[:type_id] ] ++ acc end)
      |> Enum.uniq()

    distinct_type_ids = length(type_ids)
    # recompile(); EveIndustry.Prices.process_esi_prices(10000002)
    Logger.debug("ESI market distinct types on market in region #{region}: #{distinct_type_ids}")

    # do a little pre-processing to shave off data

    order_key_filter = [
      :duration, :issued, :location_id,
      :min_volume, :order_id, :system_id,
      :volume_total
    ]

    data =
      data
      |> Enum.reduce([], fn item, acc -> [Map.drop(item, order_key_filter)] ++ acc end)

    prices =
      type_ids
      |> Map.new(fn type_id -> {type_id, calculate_price(type_id, data)} end)

    # take all of this and shove it into ETS

    for type_id <- type_ids do
      data = prices[type_id]

      Cachex.put(:min_sell_price, type_id, data[:min_sell_price])
      Cachex.put(:max_buy_price, type_id, data[:max_buy_price])

    end

    :ok

  end

  def calculate_price(type_id, data) do

    data = Enum.filter(data, fn item -> item[:type_id] == type_id end)

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

  def fetch_market_prices(region \\ 10000002) do

    # fetch the raw price market data from ESI directly
    # can take awhile at hundreds of pages

    esi_url = "https://esi.evetech.net/latest/markets/#{region}/orders/?page=1"

    {:ok, response} = Mojito.request(method: :get, url: esi_url)

    total_pages =
      response.headers
      |> Mojito.Headers.get("x-pages")
      |> String.to_integer()


    Logger.debug("Total ESI market pages in region #{region}: #{total_pages}")
    first_page = Jason.decode!(response.body, keys: :atoms)

    stream = Task.async_stream(
      2..total_pages,
      fn page -> fetch_additional_market_pages(region, page) end,
      max_concurrency: 50
    )

    rest_of_data =
      stream
      |> Enum.reduce([], fn {:ok, data}, acc -> acc ++ data end)

    first_page ++ rest_of_data
  end

  def fetch_additional_market_pages(region, page) do

    # fetch the raw price market data from ESI directly
    # can take awhile at hundreds of pages

    Logger.debug("Fetching ESI market page #{page}")

    esi_url = "https://esi.evetech.net/latest/markets/#{region}/orders/?page=#{page}"

    {:ok, response} = Mojito.request(method: :get, url: esi_url)

    Jason.decode!(response.body, keys: :atoms)

  end
end
