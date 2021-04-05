defmodule EveIndustry.Formulas do

  # https://eve-industry.org/export/IndustryFormulas.pdf

  def material_amount(_blueprint_me, _me_bonuses, 1, runs), do: runs

  def material_amount(blueprint_me, me_bonus, base_quantity, runs) do

    blueprint_bonus = 1 - blueprint_me / 100

    base_quantity * runs * blueprint_bonus * me_bonus
    |> Kernel.ceil()
    |> Kernel.max(runs)

  end
end
