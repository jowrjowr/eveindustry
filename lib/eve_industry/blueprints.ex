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
          materials: [ :name ],
          products: [ :name ]
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
          materials: [ :name ],
          products: [ :name ]
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
          materials: [ :name ],
          products: [ :name ]
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

    EveIndustry.Repo.one(query)

  end


end
