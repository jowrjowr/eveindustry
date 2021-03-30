defmodule EveIndustry.Prices do
  import Numerix.Statistics, only: [weighted_mean: 2]

  def fetch(type_id) do
    %{
      adjusted_price: Cachex.get!(:adjusted_price, type_id),
      weighted_sell_price: Cachex.get!(:weighted_sell_price, type_id),
      weighted_buy_price: Cachex.get!(:weighted_buy_price, type_id)
    }
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
    # forge 10000002
    # domain 10000043

    data = fetch_market_prices(region)

    type_ids =
      data
      |> Enum.reduce([], fn item, acc -> [ item[:type_id] ] ++ acc end)
      |> Enum.uniq()

    prices =
      type_ids
      |> Map.new(fn type_id -> {type_id, calculate_price(type_id, data)} end)

    # take all of this and shove it into ETS

    for type_id <- type_ids do
      data = prices[type_id]

      Cachex.put(:weighted_sell_price, type_id, data[:weighted_mean_sell])
      Cachex.put(:weighted_buy_price, type_id, data[:weighted_mean_buy])

    end

    :ok

  end

  def calculate_price(type_id, data) do

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

    sell_data =
      data
      |> Enum.filter(fn item -> item[:is_buy_order] == false end)
      |> Enum.filter(fn item -> item[:type_id] == type_id end)

    buy_data =
      data
      |> Enum.filter(fn item -> item[:is_buy_order] == true end)
      |> Enum.filter(fn item -> item[:type_id] == type_id end)

    # the lengths of these lists is the same so i can split the work

    sell_price = weighted_mean(
      Enum.reduce(sell_data, [], fn item, acc -> acc ++ [item[:price]] end),
      Enum.reduce(sell_data, [], fn item, acc -> acc ++ [item[:volume_remain]] end)
    )

    buy_price = weighted_mean(
      Enum.reduce(buy_data, [], fn item, acc -> acc ++ [item[:price]] end),
      Enum.reduce(buy_data, [], fn item, acc -> acc ++ [item[:volume_remain]] end)
    )

    %{
      type_id: type_id,
      weighted_mean_sell: sell_price,
      weighted_mean_buy: buy_price
    }

  end

  def fetch_market_prices(region \\ 10000002, current_page \\ 1, acc \\ []) do

    # fetch the raw price market data from ESI directly
    # can take awhile at hundreds of pages

    esi_url = "https://esi.evetech.net/latest/markets/#{region}/orders/?page=#{current_page}"

    {:ok, response} = Mojito.request(method: :get, url: esi_url)

    total_pages =
      response.headers
      |> Mojito.Headers.get("x-pages")
      |> String.to_integer()

    result = Jason.decode!(response.body, keys: :atoms)

    if current_page == total_pages do
      acc ++ result
    else
      fetch_market_prices(region, current_page + 1, acc ++ result)
    end
  end
end
