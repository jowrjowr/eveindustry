defmodule EveIndustry.Bonuses.Manufacturing do

  def rig_me_bonus(security, rig) do

    # the bonusing is the same across all structure, rig, and security permutations

    base =
      case rig do
        nil -> 1
        :t1 -> 0.98
        :t2 -> 0.976
      end

    security_multiplier =
      case security do
        :highsec -> 1
        :lowsec -> 1.9
        :nullsec -> 2.1
        :wormhole -> 2.1
      end

    1 - (1 - base) * security_multiplier

  end

  def structure_hull_me_bonus(_structure) do
    # the hull bonus, nothing else

    # sotiyo/azbel/raitaru all have same bonus.
    # won't assume retardation of building in non-bonused structure.

    0.99

  end

end
