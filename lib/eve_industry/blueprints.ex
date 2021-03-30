defmodule EveIndustry.Blueprints do
  import Ecto.Query, only: [from: 2]

  def by_groups(market_groups) do
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

    # first, fetch all blueprint typeids that belong to these groups

    query =
      from(r in EveIndustry.Schema.Blueprints,
        where: r.marketGroupID in ^market_groups and r.published == true,
        preload: [
          :materials,
          :products,
          materials: [ :name ],
          products: [ :name ]
        ]
      )

    EveIndustry.Repo.all(query)

  end

  def details(type_id) do
    # a single blueprint
    query =
      from(r in EveIndustry.Schema.Blueprints,
        where: r.typeID == ^type_id,
        preload: [
          :materials,
          :products,
          materials: [ :name ],
          products: [ :name ]
        ]
      )

    EveIndustry.Repo.one(query)

  end

  def bill_of_materials(type_id, blueprint_me, runs, bonus) do
    # determine the list of materials needed to do one run of a given blueprint typeid
    true
  end
end
