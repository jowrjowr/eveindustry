defmodule EveIndustry.Schema.IndustryActivity do
  use Ecto.Schema

  @primary_key {:typeID, :integer, autogenerate: false}
  schema "industryActivity" do
    field :activityID, :integer
    field :time, :integer
  end
end
