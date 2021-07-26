defmodule EveIndustry.Bonuses do
  alias EveIndustry.Bonuses.Manufacturing
  alias EveIndustry.Bonuses.Reactions
  # alias EveIndustry.Bonuses.Reprocessing

  def te(%{industry: :reactions, security: security, reactions: %{rig: rig, structure: structure}}) do
    # calculate reaction TE bonuses

    structure_bonus = Reactions.structure_te_bonus(structure)
    rig_bonus = Reactions.rig_te_bonus(security, rig)

    # hardcoded assumption of perfect skills
    # reactions (20%)
    skills_bonus = 0.8

    structure_bonus * rig_bonus * skills_bonus
  end

  def te(_) do
    # don't actually care about TE bonusing *anywhere* right now
    1.0
  end

  def me(:reactions, security, %{rig: rig}) do
    Reactions.rig_me_bonus(security, rig)
  end

  def me(:manufacturing, security, %{rig: rig, structure: structure}) do
    rig_bonus = Manufacturing.rig_me_bonus(security, rig)
    hull_bonus = Manufacturing.structure_hull_me_bonus(structure)

    rig_bonus * hull_bonus
  end
end
