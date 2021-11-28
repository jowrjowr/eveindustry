defmodule EveIndustry.Reactions do
  import Ecto.Query, only: [from: 2]

  def calculate(config) do
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

    reaction_market_groups = [2402, 2403, 2404, 2769]

    reactions =
      config
      |> EveIndustry.Industry.calculate()
      |> Enum.filter(fn {_type_id, %{market_group_id: x}} -> x in reaction_market_groups end)
      |> Enum.map(fn {type_id, data} ->
        slot_value = calculate_slot_value(data) * data.products.quantity

        {type_id, Map.put(data, :slot_value, slot_value)}
      end)
      |> Map.new()

    reactions
  end

  def calculate_alchemy(reactions) do
    reactions
    |> Map.to_list()
    |> Enum.filter(fn {_type_id, item} -> String.contains?(item.name, "Unrefined") == true end)
    |> Enum.reduce([], fn {type_id, data}, acc ->
      alchemy = calculate_alchemy_products(data, reactions)
      slot_value = (alchemy.unit_value - data.unit_industry_cost) * data.products.quantity

      map =
        data
        |> Map.put(:alchemy, alchemy)
        |> Map.put(:slot_value, slot_value)

      acc ++ [{type_id, map}]
    end)
    |> Map.new()
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
          reprocessing: [:name]
        ]
      )

    EveIndustry.Repo.one(query)
  end

  defp calculate_slot_value(item) do
    # need some sense of what a reaction is worth in terms of how many reaction slots
    # it and its' precursors consume

    precursor_slots =
      item.materials
      |> Enum.filter(fn {_type_id, %{industry_type: x}} -> x == :reactions end)
      |> length()

    slots = precursor_slots + 1

    (item.sell_price - item.unit_industry_cost) / slots
  end

  defp calculate_alchemy_products(item, reactions) do
    # 46172 - ferrofluid reaction formula
    # 46197 - unrefined ferrofluid reaction formula

    # the idea is to directly compare alchemy against its counterpart using raw build costs rather
    # than what the alchemy products sell for in jita, which is garbage and who cares.

    alchemy_product = EveIndustry.Ore.single_item(item.products.type_id)

    # alchemy goes either like this:
    # goo1 + goo2 + fuel block = unrefined intermediary -> goo1 + intermediary
    #
    # or like this:
    # goo1 + goo2 + fuel block = unrefined intermediary -> intermediary

    {intermediary_type_id, goo_1_type_id} = alchemy_type_ids(alchemy_product, item)

    [intermediary_unit_industry_cost] =
      reactions
      |> Enum.filter(fn {_type_id, data} -> data.products.type_id == intermediary_type_id end)
      |> Enum.map(fn {_type_id, data} -> data.unit_industry_cost end)

    goo_unit_cost = EveIndustry.Prices.sell_price(goo_1_type_id)

    alchemy_refine_portion = alchemy_product.yield[intermediary_type_id].type_data.portionSize
    intermediary_refine_amount = alchemy_product.yield[intermediary_type_id].amount / alchemy_refine_portion

    goo_refine_amount = goo_refine_amount(alchemy_product, goo_1_type_id)

    value = intermediary_refine_amount * intermediary_unit_industry_cost + goo_unit_cost * goo_refine_amount

    margin =
      case value do
        0.0 -> 0.0
        _ -> Float.round(value / item.unit_industry_cost, 2)
      end

    intermediary_name = alchemy_product.yield[intermediary_type_id].type_data.typeName

    goo_name =
      case goo_1_type_id do
        nil -> nil
        _ -> item.materials[goo_1_type_id].name
      end

    %{
      unit_value: value,
      margin: margin,
      goo: %{
        type_id: goo_1_type_id,
        name: goo_name,
        amount: goo_refine_amount * item.products.quantity
      },
      intermediary: %{
        type_id: intermediary_type_id,
        name: intermediary_name,
        amount: intermediary_refine_amount * item.products.quantity
      }
    }
  end

  defp goo_refine_amount(_alchemy_product, nil) do
    0.0
  end

  defp goo_refine_amount(alchemy_product, type_id) do
    alchemy_refine_portion = alchemy_product.yield[type_id].type_data.portionSize
    alchemy_product.yield[type_id].amount / alchemy_refine_portion
  end

  defp alchemy_type_ids(%{yield_types: [intermediary_type_id]}, _item) do
    {intermediary_type_id, nil}
  end

  defp alchemy_type_ids(%{yield_types: yield_types}, item) do
    [intermediary_type_id] = Enum.filter(yield_types, fn type_id -> type_id not in Map.keys(item.materials) end)
    [goo_1_type_id] = Enum.filter(yield_types, fn type_id -> type_id in Map.keys(item.materials) end)

    {intermediary_type_id, goo_1_type_id}
  end
end
