defmodule EveIndustry.Blueprints do
  import Ecto.Query, only: [from: 2]

  def by_groups(market_groups) do
    # first, fetch all blueprint typeids that belong to these groups

    query =
      from(r in EveIndustry.Schema.Derived.Blueprints,
        where: r.marketGroupID in ^market_groups and r.published == true,
        preload: [
          :materials,
          :products,
          :time,
          materials: [:name],
          products: [:name]
        ]
      )

    EveIndustry.Repo.all(query)
  end

  def everything() do
    # first, fetch all blueprint typeids that belong to these groups

    query =
      from(r in EveIndustry.Schema.Derived.Blueprints,
        where: r.published == true,
        preload: [
          :materials,
          :products,
          :time,
          materials: [:name],
          products: [:name]
        ]
      )

    EveIndustry.Repo.all(query)
  end

  def multiple(type_ids) do
    # multiple blueprints
    query =
      from(r in EveIndustry.Schema.Derived.Blueprints,
        where: r.typeID in ^type_ids and r.published == true,
        preload: [
          :materials,
          :products,
          materials: [:name],
          products: [:name]
        ]
      )

    EveIndustry.Repo.all(query)
  end

  def single(type_id) do
    # single blueprints
    query =
      from(r in EveIndustry.Schema.Derived.Blueprints,
        where: r.typeID == ^type_id and r.published == true,
        preload: [
          :materials,
          :products,
          materials: [:name],
          products: [:name]
        ]
      )

    EveIndustry.Repo.one(query)
  end

  def blueprint_from_type(type_id) do
    query =
      from(r in EveIndustry.Schema.IndustryActivityProducts,
        where: r.productTypeID == ^type_id,
        select: r.typeID
      )

    EveIndustry.Repo.all(query)
  end

  def to_map(blueprint) do
    %{
      blueprint: blueprint,
      type_id: blueprint.typeID,
      name: blueprint.typeName,
      group_id: blueprint.groupID,
      market_group_id: blueprint.marketGroupID,
      time: blueprint.time.time,
      industry_type: item_industry_type(blueprint.products.productTypeID)
    }
  end

  defp material_details(material) do
  end

  def item_industry_type(product_type_id) do
    # determine blueprint details, if any
    query =
      from(r in EveIndustry.Schema.IndustryActivityProducts,
        where: r.productTypeID == ^product_type_id
      )

    # alchemy breaks up "one blueprint, one result" but alchemy is still
    # reaction, so in practice this doesn't matter.

    activity_type =
      query
      |> EveIndustry.Repo.all()
      |> determine_activity_type()

    # the actual relations are stored in ramActivities
    case activity_type do
      1 -> :manufacturing
      11 -> :reactions
      _ -> nil
    end
  end

  defp determine_activity_type(nil), do: nil
  defp determine_activity_type([]), do: nil

  defp determine_activity_type(data) do
    # it doesn't matter which one, but hd(data) will always have a return.
    result = hd(data)
    result.activityID
  end
end
