defmodule EveIndustry.Schema.InvTypes do
  use Ecto.Schema

  @primary_key {:typeID, :integer, autogenerate: false}
  schema "invTypes" do
    field :groupID, :integer
    field :typeName, :string
    field :portionSize, :integer
    field :basePrice, :decimal
    field :marketGroupID, :integer
    field :published, :boolean
  end
end


# CREATE TABLE IF NOT EXISTS "invTypes" (
# 	"typeID" INTEGER NOT NULL,
# 	"groupID" INTEGER,
# 	"typeName" VARCHAR(100),
# 	description TEXT,
# 	mass FLOAT,
# 	volume FLOAT,
# 	capacity FLOAT,
# 	"portionSize" INTEGER,
# 	"raceID" INTEGER,
# 	"basePrice" DECIMAL(19, 4),
# 	published BOOLEAN,
# 	"marketGroupID" INTEGER,
# 	"iconID" INTEGER,
# 	"soundID" INTEGER,
# 	"graphicID" INTEGER,
# 	PRIMARY KEY ("typeID"),
# 	CONSTRAINT invtype_published CHECK (published IN (0, 1))
# );
