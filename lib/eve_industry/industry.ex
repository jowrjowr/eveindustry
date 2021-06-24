defmodule EveIndustry.Industry do
  alias EveIndustry.Blueprints
  alias EveIndustry.Bonuses
  import EveIndustry.Formulas, only: [material_amount: 4]

  def calculate(industry, blueprint_groups, batch_size \\ 100, security \\ :lowsec, rig \\ :t2, structure \\ :athanor) do

    te_bonus = Bonuses.te(industry, security, rig, structure)
    me_bonus = Bonuses.me(industry, security, rig, structure)

    industry_from_market =
      blueprint_groups
      |> Blueprints.by_groups()
      |> Enum.reduce([], fn item, acc -> acc ++ [{item.typeID, calculate_details(item, me_bonus, te_bonus, batch_size)}] end)
      |> Map.new()

    # need to feed this data back into itself so multi-level blueprints can be priced using previously constructed products
    # TODO: make this not look like shit.

    industry =
      industry_from_market
      |> Enum.reduce([], fn {type_id, data}, acc ->
        industry_value = calculate_industry_prices(type_id, industry_from_market)
        map =
          data
          |> Map.put(:build_from_industry_value, industry_value)
        acc ++ [{type_id, map}]
      end)
      |> Map.new()

      industry
  end

  def calculate_industry_prices(type_id, data) do
    # recursively cycle through the blueprints to calculate the next level from previous

    # only recurse into these item groups for prices
    # will add to as necessary

    industry_price_groups = [712, 428]

    # make sure all the data needed to calculate exists

    industry_unit_value =
      data
      |> Map.get(type_id)
      |> Map.get(:materials)
      |> Enum.reduce(0, fn {material_type_id, %{group_id: group_id}}, acc ->
        value =
          case Enum.member?(industry_price_groups, group_id) do

            true ->
              {_, result} =
                data
                |> Enum.filter(fn {_, item} -> item[:products][:type_id] == material_type_id end)
                |> hd()
              Map.get(result, :build_from_industry_value)

            false ->
              Cachex.get!(:min_sell_price, material_type_id)
          end

        case {value, acc} do
          {nil, _} -> nil
          {_, nil} -> nil
          {_, _} -> acc + value
        end

      end)

    industry_unit_value =
      case industry_unit_value do
        nil -> 0
        _ -> industry_unit_value
      end

    case data[type_id][:products][:group_id] do
      428 -> nil
      _ -> industry_unit_value / data[type_id][:products][:quantity]
    end

  end

  def calculate_details(data, me_bonus, te_bonus, batch_size) do

    # hardcode for now

    solar_system_id = 30002538

    materials =
      data.materials
      |> Enum.reduce([], fn material, acc ->
        result = %{
          type_id: material.materialTypeID,
          group_id: material.name.groupID,
          name: material.name.typeName,
          quantity: material_amount(0, me_bonus, material.quantity, batch_size)
        }
        acc ++ [{ material.materialTypeID, result}]
      end)
      |> Map.new()

    build_time = batch_size * data.time.time * te_bonus
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
        false -> 0
        true ->
          Enum.reduce(materials, 0, fn {type_id, materials}, acc ->
            quantity = materials[:quantity]
            acc + Cachex.get!(:min_sell_price, type_id) * quantity / build_quantity
          end)
      end

    reprocessing = EveIndustry.Ore.single_item(data.products.productTypeID)

    unit_value = unit_material_price + unit_tax

    sell_price =
      case Cachex.get!(:min_sell_price, data.products.productTypeID) do
        nil -> 0
        x -> Float.round(x, 2)
      end

    buy_price =
      case Cachex.get!(:max_buy_price, data.products.productTypeID) do
        nil -> 0
        x -> Float.round(x, 2)
      end

    sell_margin =
      case sell_price do
        0 -> 0
        _ -> Float.round(sell_price / unit_value, 4) |> Float.round(2)
      end

    buy_margin =
      case buy_price do
        0 -> 0
        _ -> Float.round(buy_price / unit_value, 4) |> Float.round(2)
      end

    profitable = sell_margin < 1 || buy_margin < 1

    reprocessing_margin =
      case unit_value do
        0 -> 0
        _ -> Float.round(reprocessing[:unit_value] / unit_value, 4) |> Float.round(2)
      end

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
      build_from_industry_value: unit_value,
      unit_tax: unit_tax,
      products: products,
      profitable: profitable,
      profitable_to_reprocess: profitable_to_reprocess,
      reprocessing_margin: reprocessing_margin
    }

  end

end
