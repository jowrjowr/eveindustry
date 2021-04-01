defmodule EveIndustry.Ore do
  import Ecto.Query, only: [from: 2]
  require Logger

  def compressed(security \\ :lowsec, implant \\ true, rig \\ :t2, structure \\ :athanor) do

    # easier to hardcode all the fucking compressed ore type ids

    # naughty list. not ore.
    excluded = [41139, 41144, 47450]

    query =
      from(r in EveIndustry.Schema.Derived.Reprocessing,
        where: r.typeID not in ^excluded,
        where: r.published == true,
        where: like(r.typeName, "Compressed%"),
        preload: [
          :reprocessing,
          reprocessing: [ :name ]
        ]
      )

    sde_ore = EveIndustry.Repo.all(query)

    # now the idea is to calculate out what each type_id refines into, and how much.

    ore =
      sde_ore
      |> Enum.reduce([], fn item, acc -> [ item.typeID ] ++ acc end)
      |> Map.new(fn type_id -> {
        type_id,
        calculate_price(
          type_id,
          Enum.filter(sde_ore, fn item -> item.typeID == type_id end),
          bonuses(implant, structure, security, rig)
        )
      }
      end)

    ore
  end


  defp calculate_price(type_id, data, refine_fraction) do
    # reduce down the SDE spew to something a little more managable:
    # [{material, quantity}, ...]

    yield =
      data
      |> hd()
      |> Map.from_struct()
      |> Map.get(:reprocessing)
      |> IO.inspect()
      |> Enum.reduce([], fn item, acc ->
        acc ++ [{item.materialTypeID, item.quantity * refine_fraction}]
      end)

    unit_value =
      yield
      |> Enum.reduce(0, fn {type_id, amount}, acc ->
        acc + Cachex.get!(:min_sell_price, type_id) * amount
      end)

    yield =
      yield
      |> Map.new(fn {type_id, amount} -> {type_id, %{ type_id: type_id, amount: amount} } end)

    yield_types = Map.keys(yield)

    %{
      :unit_value => unit_value,
      :min_sell_value => Cachex.get!(:min_sell_price, type_id),
      :yield => yield,
      :yield_types => yield_types
    }

  end

  defp bonuses(implant, structure, security, rig) do
    # calculate reprocessing bonuses

    implant_bonus = implant_bonus(implant)
    structure_bonus = structure_bonus(structure)
    rig_bonus = rig_bonus(security, rig)

    # hardcoded assumption of perfect skills
    # reprocessing (15%), reprocessing efficiency(10%), ore-specific (10%)
    skills_bonus = 1.15 * 1.1 * 1.1

    implant_bonus * structure_bonus * rig_bonus * skills_bonus
  end

  defp rig_bonus(security, rig) do

    # the bonusing is the same across all structure, rig, and security permutations

    base =
      case rig do
        nil -> 0.50
        :t1 -> 0.51
        :t2 -> 0.53
      end

    security_multiplier =
      case security do
        :highsec -> 1
        :lowsec -> 1.06
        :nullsec -> 1.12
        :wormhole -> 1.12
      end

    base * security_multiplier

  end

  defp structure_bonus(structure) do
    # the hull bonus, nothing else

    case structure do
      :athanor -> 1.02
      :tatara -> 1.04
    end
  end

  defp implant_bonus(implant) do
    # only suckers use the 1 or 2% implants
    case implant do
      true -> 1.04
      false -> 1
    end
  end

end
