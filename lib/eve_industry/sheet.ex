defmodule EveIndustry.Sheet do
  alias EveIndustry.Blueprints
  alias EveIndustry.Industry
  import Ecto.Query, only: [from: 2]

  def item_list(config, items) do
    data = Industry.calculate(config)

    blueprints =
      Enum.reduce(items, [], fn item_id, acc ->
        acc ++ Blueprints.blueprint_from_type(item_id)
      end)

    material_types =
      blueprints
      |> Enum.reduce([], fn blueprint_id, acc ->
        item_materials = data[blueprint_id].materials
        acc ++ Map.keys(item_materials)
      end)
      |> Enum.uniq()

    # print out the material column
    Enum.each(material_types, fn type_id ->
      query =
        from(r in EveIndustry.Schema.InvTypes,
          where: r.typeID == ^type_id,
          select: r.typeName
        )

      result = EveIndustry.Repo.one(query)
      IO.inspect(result)
    end)

    # print out the materials
    Enum.each(blueprints, fn blueprint_id ->
      IO.puts("\n")

      Enum.each(material_types, fn type_id ->
        blueprint_mats = data[blueprint_id].materials
        type_data = Map.get(blueprint_mats, type_id, %{})
        quantity = Map.get(type_data, :quantity, 0)
        IO.puts(quantity)
      end)
    end)
  end
end
