defmodule EveIndustry.Bonuses.Reactions do

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
        :lowsec -> 1
        :nullsec -> 1.1
        :wormhole -> 1.1
      end

    1 - (1 - base) * security_multiplier

  end

  def rig_te_bonus(security, rig) do

    base =
      case rig do
        nil -> 1
        :t1 -> 0.8
        :t2 -> 0.76
      end

    security_multiplier =
      case security do
        :lowsec -> 1
        :nullsec -> 1.1
        :wormhole -> 1.1
      end

    1 - (1 - base) * security_multiplier

  end

  def structure_te_bonus(structure) do
    # the hull bonus, nothing else

    case structure do
      :athanor -> 1
      :tatara -> 0.75
    end
  end
end
