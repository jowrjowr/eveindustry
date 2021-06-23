defmodule EveIndustry.Reactions do
  import Ecto.Query, only: [from: 2]
  import EveIndustry.Formulas, only: [material_amount: 4]

  def calculate(batch_size \\ 100, security \\ :lowsec, rig \\ :t2, structure \\ :athanor) do

    # non-blueprint reaction market groups

    # 499: advanced moon materials
    # 1858: booster materials
    # 500: processed moon materials
    # 1860: polymer materials
    # 501: raw moon materials

    # reaction blueprint groups

    # 2402: biochemical reaction formulas
    # 2403: composite
    # 2404: polymer

    reaction_groups = [2402, 2403, 2404, 2769]


    te_bonus = te_bonuses(security, rig, structure)
    me_bonus = me_bonuses(security, rig)

    reactions_from_market =
      reaction_groups
      |> EveIndustry.Blueprints.by_groups()
      |> Enum.reduce([], fn item, acc -> acc ++ [{item.typeID, calculate_details(item, me_bonus, te_bonus, batch_size)}] end)
      |> Map.new()

    # need to feed this data back into itself so intermediary/advanced/alchemy materials
    # can be priced using previously constructed products

    reactions =
      reactions_from_market
      |> Enum.reduce([], fn {type_id, data}, acc ->
        industry_value = calculate_industry_prices(type_id, reactions_from_market)
        alchemy = alchemy(data.products.name)
        alchemy_value = calculate_alchemy_price(alchemy, reactions_from_market)

        alchemy_margin =
          case alchemy_value do
            0.0 -> 0.0
            _ -> Float.round(data.build_from_market_value / alchemy_value, 2)
          end
        alchemy_profitable = alchemy_margin < 1

        map =
          data
          |> Map.put(:build_from_industry_value, industry_value)
          |> Map.put(:alchemy_margin, alchemy_margin)
          |> Map.put(:alchemy_profitable, alchemy_profitable)
          |> Map.put(:build_from_alchemy_value, alchemy_value)
        acc ++ [{type_id, map}]
      end)
      |> Enum.filter(fn {_type_id, item} -> String.contains?(item.name, "Unrefined") == false end)
      |> Map.new()

    reactions
  end

  def alchemy(type_name) do

    unrefined_type_name = "Unrefined #{type_name}"
    query =
      from(r in EveIndustry.Schema.Derived.Reprocessing,
        where: r.published == true,
        where: r.groupID == 428,
        where: r.typeName == ^unrefined_type_name,
        preload: [
          :reprocessing,
          reprocessing: [ :name ]
        ]
      )

    EveIndustry.Repo.one(query)

  end

  defp calculate_alchemy_price(nil, _), do: 0.0

  defp calculate_alchemy_price(%{typeID: alchemy_product_type_id}, reactions) do

    # 46172 - ferrofluid reaction formula
    # 46197 - unrefined ferrofluid reaction formula

    # the idea is to directly compare alchemy against its counterpart using raw build costs


    {_, alchemy_data} =
      reactions
      |> Enum.filter(fn {_type_id, data} -> data.products.type_id == alchemy_product_type_id end)
      |> hd()

    # there is always an alchemy product, but not always a goo product

    alchemy_product =
      alchemy_data.products.reprocessing.yield
      |> alchemy_product_yield()

    #...but not always a goo product

    alchemy_goo_product =
      alchemy_data.products.reprocessing.yield
      |> alchemy_goo_yield()

    alchemy_goo_value =
      case alchemy_goo_product do
        nil -> 0.0
        _ -> EveIndustry.Prices.fetch(alchemy_goo_product[:type_id])[:min_sell_price] * alchemy_goo_product[:amount]
      end

    # the desired result is the unit value of the alchemy main product
    # industry/market value are the same here.

    ( alchemy_data[:build_from_market_value] - alchemy_goo_value ) / alchemy_product[:amount]

  end

  defp alchemy_product_yield(data) do
    {_, result} =
      data
      |> Enum.filter(fn {_type_id, item} -> item.type_data.marketGroupID == 500 end)
      |> hd()

    result
  end

  defp alchemy_goo_yield([]), do: nil

  defp alchemy_goo_yield(data) do
    result =
      data
      |> Enum.filter(fn {_type_id, item} -> item.type_data.marketGroupID == 501 end)

    case result do
      [] -> nil
      [{_, data}] -> data

    end

  end

  def calculate_alchemy(batch_size \\ 100, security \\ :lowsec, rig \\ :t2, structure \\ :athanor) do

    # the reaction group isn't exclusive to just alchemy, annoyingly

    reaction_groups = [2403]

    te_bonus = te_bonuses(security, rig, structure)
    me_bonus = me_bonuses(security, rig)

    # the alchemy product has to be melted. it in of itself is useless.

    reactions =
      reaction_groups
      |> EveIndustry.Blueprints.by_groups()
      |> Enum.filter(fn item -> String.contains?(item.typeName, "Unrefined") == true end)
      |> Enum.reduce([], fn item, acc -> acc ++ [{item.typeID, calculate_details(item, me_bonus, te_bonus, batch_size)}] end)
      |> Map.new()

    reactions
  end

#  defp calculate_industry_prices(_type_id, data), do: data

  defp calculate_industry_prices(type_id, data) do
    # recursively cycle through the reaction blueprints to calculate the next level from previous

    # only recurse into these item groups for prices

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

  defp calculate_details(data, me_bonus, te_bonus, batch_size) do

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

  defp te_bonuses(security, rig, structure) do
    # calculate reaction TE bonuses

    structure_bonus = structure_te_bonus(structure)
    rig_bonus = rig_te_bonus(security, rig)

    # hardcoded assumption of perfect skills
    # reactions (20%)
    skills_bonus = 0.8

    structure_bonus * rig_bonus * skills_bonus
  end

  defp me_bonuses(security, rig) do

    rig_me_bonus(security, rig)

  end

  defp rig_me_bonus(security, rig) do

    # the bonusing is the same across all structure, rig, and security permutations

    base =
      case rig do
        nil -> 1
        :t1 -> 0.98
        :t2 -> 0.976
      end

    security_multiplier =
      case security do
        :lowsec -> 1
        :nullsec -> 1.1
        :wormhole -> 1.1
      end

    1 - (1 - base) * security_multiplier

  end

  defp rig_te_bonus(security, rig) do

    base =
      case rig do
        nil -> 1
        :t1 -> 0.8
        :t2 -> 0.76
      end

    security_multiplier =
      case security do
        :lowsec -> 1
        :nullsec -> 1.1
        :wormhole -> 1.1
      end

    1 - (1 - base) * security_multiplier

  end

  defp structure_te_bonus(structure) do
    # the hull bonus, nothing else

    case structure do
      :athanor -> 1
      :tatara -> 0.75
    end
  end

end
