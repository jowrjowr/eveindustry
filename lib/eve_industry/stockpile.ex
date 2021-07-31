defmodule EveIndustry.Stockpile do
  import Ecto.Query, only: [from: 2]

  def parse(file \\ "priv/stockpile.txt") do
    # this just parses the jeveassets stockpile copy+paste
    {:ok, contents} = File.read(file)

    :ok =
      contents
      |> String.split("\n", trim: true)
      |> Enum.reduce([], fn line, acc -> acc ++ [String.split(line, "\t", trim: true)] end)
      |> Enum.each(fn [_, _, _, _, _, item_name, amount | _] ->
        case lookup_item_type(item_name) do
          nil ->
            :ok

          type_id ->
            amount = String.to_integer(amount)
            {:ok, true} = Cachex.put(:stockpile, type_id, amount)
        end
      end)
  end

  def lookup_item_type(type_name) do
    query =
      from(r in EveIndustry.Schema.InvTypes,
        where: r.typeName == ^type_name,
        select: r.typeID
      )

    EveIndustry.Repo.one(query)
  end
end
