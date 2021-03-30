defmodule EveIndustry.Schema.IndustryActivityProducts do
  use Ecto.Schema

  @primary_key {:typeID, :integer, autogenerate: false}
  schema "industryActivityProducts" do
    field :activityID, :integer
    field :productTypeID, :integer
    field :quantity, :integer

    has_one :name, EveIndustry.Schema.InvTypes,
      references: :productTypeID,
      foreign_key: :typeID
  end
end
