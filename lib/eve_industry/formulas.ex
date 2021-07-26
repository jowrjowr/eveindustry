defmodule EveIndustry.Formulas do
  # quantity = Formulas.material_amount(0, me_bonus, material.quantity, batch_size)
  # tax_quantity = Formulas.material_amount(0, 1.0, material.quantity, batch_size)

  def material_amount(_blueprint_me, _me_bonuses, 1, runs), do: runs

  def material_amount(blueprint_me, me_bonus, base_quantity, runs) do
    # https://eve-industry.org/export/IndustryFormulas.pdf

    blueprint_bonus = 1 - blueprint_me / 100

    (base_quantity * runs * blueprint_bonus * me_bonus)
    |> Kernel.ceil()
    |> Kernel.max(runs)
  end

  def cost_index(job_type, solar_system_id) do
    case job_type do
      :manufacturing -> Cachex.get!(:manufacturing_cost_index, solar_system_id)
      :reactions -> Cachex.get!(:reaction_cost_index, solar_system_id)
      nil -> 1.0
    end
  end
end
