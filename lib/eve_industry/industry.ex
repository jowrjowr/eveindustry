defmodule EveIndustry.Industry do
  alias EveIndustry.Blueprints
  alias EveIndustry.Bonuses
  import EveIndustry.Formulas, only: [material_amount: 4]

  def calculate(config) do
    items =
      Blueprints.everything()
      |> Enum.filter(fn item -> item.products != nil end)
      |> Task.async_stream(fn item -> {item.typeID, calculate_details(item, config)} end)
      |> Enum.reduce([], fn {:ok, {type_id, data}}, acc -> [{type_id, data}] ++ acc end)
      |> Map.new()

    # industry flow, at maximum
    # cap ship -> cap component -> component -> adv reaction -> intermediate reaction -> fuel block
    # 6 levels worst case

    industry =
      items
      |> Map.new(fn item -> calculate_industry_prices(item, items) end)

    industry
  end

  def calculate_industry_prices({type_id, data}, items) do
    # attempt to calculate the build value of an item using previously calculated values

    debug = type_id == 38661

    industry_unit_value =
      data.materials
      |> Enum.reduce(0, fn {material_type_id, material_data}, acc ->
        # if debug do
        #   IO.inspect(material_data)
        #   IO.inspect(material_type_id)
        #   IO.inspect(Blueprints.blueprint_from_type(material_type_id))
        # end

        value =
          case Blueprints.blueprint_from_type(material_type_id) do
            [] ->
              # means there is no blueprint to build this from. buy it from the market.
              material_data.quantity * material_data.sell_price

            x ->
              material_blueprint_type_id = hd(x)

              # is built from a blueprint. only use that price if it is nonzero.
              item = Map.get(items, material_blueprint_type_id, %{})
              build_from_industry_value = Map.get(item, :build_from_industry_value, 0)

              if debug do
                IO.inspect(item)
              end

              material_data.quantity * build_from_industry_value
          end

        acc + value
      end)

    data = Map.replace(data, :industry_unit_value, industry_unit_value)

    {type_id, data}
  end

  defp material_details(config, material) do
    material_type_id = material.materialTypeID
    industry_type = Blueprints.item_industry_type(material_type_id)

    me_bonus = Bonuses.me(config)

    batch_size = config.batch_size
    blueprint_me = config.blueprint_me

    %{
      type_id: material_type_id,
      group_id: material.name.groupID,
      name: material.name.typeName,
      quantity: material_amount(blueprint_me, me_bonus, material.quantity, batch_size),
      industry_type: industry_type,
      buy_price: buy_price(material_type_id),
      sell_price: sell_price(material_type_id)
    }
  end

  def calculate_details(data, config) do
    solar_system_id = config.solar_system_id
    batch_size = config.batch_size

    materials =
      data.materials
      |> Enum.reduce([], fn material, acc ->
        material_type_id = material.materialTypeID
        result = material_details(config, material)
        [{material_type_id, result}] ++ acc
      end)
      |> Map.new()

    # batch_size * data.time.time * te_bonus
    build_time = 0
    build_quantity = data.products.quantity * batch_size

    unit_tax =
      data.materials
      |> Enum.reduce(0, fn material, acc ->
        tax_quantity = material_amount(0, 0, material.quantity, batch_size)
        cost_index = Cachex.get!(:reaction_cost_index, solar_system_id)

        adjusted_price =
          case Cachex.get!(:adjusted_price, material.materialTypeID) do
            nil -> 0
            price -> price
          end

        acc + tax_quantity * adjusted_price * cost_index / build_quantity
      end)

    # not every reaction (eg, drugs) has reaction stuff on the market
    # need to see if it even makes sense to calculate a unit value

    calculate_unit_value =
      Enum.reduce(materials, true, fn {type_id, _materials}, acc ->
        acc && Cachex.get!(:min_sell_price, type_id) != nil
      end)

    unit_material_price =
      case calculate_unit_value do
        false ->
          0

        true ->
          Enum.reduce(materials, 0, fn {type_id, materials}, acc ->
            quantity = materials[:quantity]
            acc + Cachex.get!(:min_sell_price, type_id) * quantity / build_quantity
          end)
      end

    reprocessing = EveIndustry.Ore.single_item(data.products.productTypeID)

    unit_value = unit_material_price + unit_tax

    sell_price = sell_price(data.products.productTypeID)
    buy_price = buy_price(data.products.productTypeID)

    sell_margin = margin(sell_price, unit_value)
    buy_margin = margin(buy_price, unit_value)
    reprocessing_margin = reprocessing_margin(reprocessing[:unit_value], unit_value)

    profitable = sell_margin < 1 || buy_margin < 1
    profitable_to_reprocess = reprocessing_margin > 1

    products = %{
      type_id: data.products.productTypeID,
      name: data.products.name.typeName,
      group_id: data.products.name.groupID,
      quantity: build_quantity,
      sell_price: sell_price,
      sell_margin: sell_margin,
      buy_price: buy_price,
      buy_margin: buy_margin,
      reprocessing: reprocessing
    }

    %{
      type_id: data.typeID,
      name: data.typeName,
      group_id: data.groupID,
      market_group_id: data.marketGroupID,
      time: build_time,
      materials: materials,
      build_from_market_value: unit_value,
      build_from_industry_value: 0.0,
      products: products,
      profitable: profitable,
      profitable_to_reprocess: profitable_to_reprocess,
      reprocessing_margin: reprocessing_margin
    }
  end

  defp margin(_market_price, unit_value) when unit_value == 0, do: 0.0
  defp margin(market_price, _unit_value) when market_price == 0, do: 0.0

  defp margin(market_price, value) do
    Float.round(market_price / value, 2)
  end

  defp reprocessing_margin(reprocessing_unit_value, _value) when reprocessing_unit_value == 0,
    do: 0.0

  defp reprocessing_margin(_reprocessing_unit_value, value) when value == 0, do: 0.0

  defp reprocessing_margin(reprocessing_unit_value, value) do
    Float.round(reprocessing_unit_value / value, 2)
  end

  defp sell_price(type_id) do
    case Cachex.get!(:min_sell_price, type_id) do
      nil -> 0.0
      x -> Float.round(x, 2)
    end
  end

  defp buy_price(type_id) do
    case Cachex.get!(:max_buy_price, type_id) do
      nil -> 0.0
      x -> Float.round(x, 2)
    end
  end
end
