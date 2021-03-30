defmodule EveIndustry.Schema.IndustryActivityMaterials do
  use Ecto.Schema

  @primary_key {:typeID, :integer, autogenerate: false}
  schema "industryActivityMaterials" do
    field :activityID, :integer
    field :materialTypeID, :integer
    field :quantity, :integer

    has_one :name, EveIndustry.Schema.InvTypes,
      references: :materialTypeID,
      foreign_key: :typeID
  end
end
