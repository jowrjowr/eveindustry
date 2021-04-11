defmodule EveIndustry.Bonuses do

  def me_bonuses(:industry, structure, security, rig) do

    structure_bonus = structure_me_bonus(structure)
    rig_bonus = rig_me_bonus(:industry, security, rig)

    structure_bonus * rig_bonus

  end

  def me_bonuses(:reactions, structure, security, rig) do

    rig_me_bonus(:reactions, security, rig)

  end

  defp rig_me_bonus(:reactions, security, rig) do

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

  defp rig_me_bonus(:industry, security, rig) do

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

  defp structure_me_bonus(structure) do
    # the hull bonus, nothing else

    case structure do
      _ -> 0.99
    end
  end

end
