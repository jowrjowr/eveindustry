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

  def details(type_id) do
    # a single blueprint
    query =
      from(r in EveIndustry.Schema.Derived.Blueprints,
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
