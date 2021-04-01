defmodule EveIndustry.Schema.Derived.Reprocessing do
  use Ecto.Schema

  @primary_key {:typeID, :integer, autogenerate: false}
  schema "invTypes" do
    field :groupID, :integer
    field :typeName, :string
    field :portionSize, :integer
    field :basePrice, :decimal
    field :marketGroupID, :integer
    field :published, :boolean

    has_many :reprocessing, EveIndustry.Schema.InvTypeMaterials,
      references: :typeID,
      foreign_key: :typeID
  end
end
