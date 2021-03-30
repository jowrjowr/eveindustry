defmodule EveIndustry.Schema.InvNames do
  use Ecto.Schema

  @primary_key {:itemID, :integer, autogenerate: false}
  schema "invNames" do
    field :itemName, :string
  end
end
