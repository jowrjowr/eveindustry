defmodule EveIndustry.Schema.Derived.Blueprints do
  use Ecto.Schema

  @primary_key {:typeID, :integer, autogenerate: false}
  schema "invTypes" do
    field :groupID, :integer
    field :typeName, :string
    field :portionSize, :integer
    field :basePrice, :decimal
    field :marketGroupID, :integer
    field :published, :boolean

    has_many :materials, EveIndustry.Schema.IndustryActivityMaterials,
      references: :typeID,
      foreign_key: :typeID
    has_one :products, EveIndustry.Schema.IndustryActivityProducts,
      references: :typeID,
      foreign_key: :typeID

    has_one :time, EveIndustry.Schema.IndustryActivity,
      references: :typeID,
      foreign_key: :typeID
  end
end
