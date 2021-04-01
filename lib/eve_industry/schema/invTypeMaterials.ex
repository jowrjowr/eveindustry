defmodule EveIndustry.Schema.InvTypeMaterials do
  use Ecto.Schema

  @primary_key {:typeID, :integer, autogenerate: false}
  schema "invTypeMaterials" do
    field :materialTypeID, :integer
    field :quantity, :integer

    has_one :name, EveIndustry.Schema.InvTypes,
      references: :materialTypeID,
      foreign_key: :typeID
  end
end
