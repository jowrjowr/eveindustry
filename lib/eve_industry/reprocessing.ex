defmodule EveIndustry.Ore do
  import Ecto.Query, only: [from: 2]
  require Logger

  def all_alchemy() do
    query =
      from(r in EveIndustry.Schema.Derived.Reprocessing,
        where: r.published == true,
        where: r.groupID == 428,
        where: like(r.typeName, "Unrefined%"),
        preload: [
          :reprocessing,
          reprocessing: [:name]
        ]
      )

    alchemy = EveIndustry.Repo.all(query)

    # scrapmetal only benefits from the implant and base reprocessing yield. no rigs affect it.

    unrefined =
      alchemy
      |> Enum.reduce([], fn item, acc -> [item.typeID] ++ acc end)
      |> Map.new(fn type_id ->
        {
          type_id,
          calculate_prices(
            type_id,
            Enum.filter(alchemy, fn item -> item.typeID == type_id end),
            scrapmetal_bonuses()
          )
        }
      end)

    unrefined
  end

  def single_item(type_id) do
    query =
      from(r in EveIndustry.Schema.Derived.Reprocessing,
        where: r.typeID == ^type_id,
        preload: [
          :reprocessing,
          reprocessing: [:name]
        ]
      )

    data = EveIndustry.Repo.all(query)

    # scrapmetal only benefits from the implant and base reprocessing yield. no rigs affect it.

    calculate_prices(
      type_id,
      data,
      scrapmetal_bonuses()
    )
  end

  def compressed(security \\ :lowsec, implant \\ :four_percent, rig \\ :t2, structure \\ :athanor) do
    # easier to hardcode all the fucking compressed ore type ids

    # exclude this stuff
    not_ore = [41139, 41144, 47450]
    ice_ores = Enum.to_list(28433..28444)

    excluded = not_ore ++ ice_ores

    included = []

    query =
      from(r in EveIndustry.Schema.Derived.Reprocessing,
        where: r.typeID not in ^excluded,
        where: r.published == true,
        where: like(r.typeName, "Compressed%"),
        or_where: r.typeID in ^included,
        preload: [
          :reprocessing,
          reprocessing: [:name]
        ]
      )

    sde_ore = EveIndustry.Repo.all(query)

    # now the idea is to calculate out what each type_id refines into, and how much.

    ore =
      sde_ore
      |> Enum.reduce([], fn item, acc -> [item.typeID] ++ acc end)
      |> Map.new(fn type_id ->
        {
          type_id,
          calculate_prices(
            type_id,
            Enum.filter(sde_ore, fn item -> item.typeID == type_id end),
            bonuses(implant, structure, security, rig)
          )
        }
      end)

    ore
  end

  defp calculate_prices(type_id, data, refine_fraction) do
    # reduce down the SDE spew to something a little more managable:
    # [{material, quantity}, ...]

    data = hd(data)

    yield =
      data
      |> Map.from_struct()
      |> Map.get(:reprocessing)
      |> Enum.reduce([], fn item, acc ->
        acc ++
          [{item.materialTypeID, item.quantity * refine_fraction / data.portionSize, item.name}]
      end)

    unit_value =
      yield
      |> Enum.reduce(0, fn {type_id, amount, _}, acc ->
        case Cachex.get!(:min_sell_price, type_id) do
          nil -> 0
          x -> acc + x * amount
        end
      end)

    unit_value =
      case unit_value do
        0 -> 0.0
        _ -> Float.round(unit_value, 2)
      end

    yield =
      yield
      |> Map.new(fn {type_id, amount, type_data} ->
        {type_id, %{type_id: type_id, amount: amount, type_data: type_data}}
      end)

    yield_types = Map.keys(yield)

    sell_price =
      case Cachex.get!(:min_sell_price, type_id) do
        nil -> 0
        x -> Float.round(x, 2)
      end

    buy_price =
      case Cachex.get!(:max_buy_price, type_id) do
        nil -> 0
        x -> Float.round(x, 2)
      end

    sell_margin =
      case sell_price do
        0 -> 0
        _ -> Float.round(unit_value / sell_price, 4)
      end

    buy_margin =
      case buy_price do
        0 -> 0
        _ -> Float.round(unit_value / buy_price, 4)
      end

    profitable = sell_margin > 1 || buy_margin > 1

    %{
      :unit_value => unit_value,
      :sell_price => sell_price,
      :buy_price => buy_price,
      :sell_margin => sell_margin,
      :buy_margin => buy_margin,
      :yield => yield,
      :yield_types => yield_types,
      :name => data.typeName,
      :profitable => profitable
    }
  end

  defp scrapmetal_bonuses() do
    # calculate reprocessing bonuses

    # the only case that gives more than 50% yield are legacy nullsec structures with legacy rigs.
    # everything else is 50%

    base_yield = 0.5

    # hardcoded assumption of perfect skills
    # scrapmetal processing only skill that helps

    skills_bonus = 1.1

    base_yield * skills_bonus
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
      :station -> 1
      :athanor -> 1.02
      :tatara -> 1.04
    end
  end

  defp implant_bonus(implant) do
    # only suckers use the 1 or 2% implants
    case implant do
      :four_percent -> 1.04
      _ -> 1
    end
  end
end
