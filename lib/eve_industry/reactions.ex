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

    reactions =
      reactions
      |> Enum.reduce([], fn {type_id, data}, acc ->
        alchemy = alchemy(data.products.name)
        # alchemy_value = calculate_alchemy_price(alchemy, reactions)
        alchemy_value = 0.0

        alchemy_margin =
          case alchemy_value do
            0.0 -> 0.0
            _ -> Float.round(data.unit_market_cost / alchemy_value, 2)
          end

        alchemy_profitable = alchemy_margin < 1

        map =
          data
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
          reprocessing: [:name]
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

    # there is always an alchemy product

    alchemy_product =
      alchemy_data.products.reprocessing.yield
      |> alchemy_product_yield()

    # ...but not always a goo product

    alchemy_goo_product =
      alchemy_data.products.reprocessing.yield
      |> alchemy_goo_yield()

    alchemy_goo_value =
      case alchemy_goo_product do
        nil ->
          0.0

        _ ->
          EveIndustry.Prices.fetch(alchemy_goo_product[:type_id])[:min_sell_price] *
            alchemy_goo_product[:amount]
      end

    # the desired result is the unit value of the alchemy main product
    # industry/market value are the same here.

    (alchemy_data[:unit_market_cost] - alchemy_goo_value) / alchemy_product[:amount]
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
end
