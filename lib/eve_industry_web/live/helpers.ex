defmodule EveIndustryWeb.Live.Helpers do

  def choose_group(%{materials: materials}, target_group) do
    Enum.reduce(materials, [], fn {_type_id, %{group_id: group_id, name: name}}, acc  ->
      if group_id == target_group do
        acc ++ [name]
      else
        acc
      end
    end)
  end

  def reaction_fuel(%{materials: materials}) do

    result =
      materials
      |> Enum.filter(fn {type_id, %{group_id: group_id}} -> group_id == 1136 end)
      |> Enum.reduce(nil, fn {_, %{name: name, quantity: quantity}}, acc -> {name, quantity}  end)

    case result do
      nil ->
        %{name: nil, quantity: nil}
      {name, quantity} ->
        %{
          name: trim_fuel(name),
          quantity: format_number(quantity)
        }
    end

  end

  def reaction_inputs(%{materials: materials}, index) do

    result =
      materials
      |> Enum.filter(fn {type_id, %{group_id: group_id}} -> group_id != 1136 end)
      |> Enum.reduce([], fn {_, %{name: name, quantity: quantity}}, acc -> acc ++ [{name, quantity}]  end)
      |> Enum.at(index)

    case result do
      nil -> %{name: nil, quantity: nil}
      {name, quantity} -> %{name: name, quantity: format_number(quantity)}
    end

  end

  def trim_booster_name(string) do
    string
    |> String.replace("Pure ", "")
    |> String.replace(" Booster", "")
  end

  def trim_fuel(string), do: String.replace(string, " Fuel Block", "")
  def trim_formula(string), do: String.replace(string, " Reaction Formula", "")

  def select_reaction_structure() do

    [
      "Athanor": :athanor,
      "Tatara": :tatara,
      "Station": :station
    ]
  end

  def select_refine_implant() do

    [
      "4%": :four_percent,
      "I'm poor": :garbage
    ]
  end

  def select_security() do

    [
      "Lowsec": :lowsec,
      "Nullsec": :nullsec,
      "Highsec": :highsec,
      "Wormhole": :wormhole
    ]
  end

  def select_reaction_rig() do

    [
      "T2": :t2,
      "T1": :nullsec,
      "None": nil
    ]
  end

  def format_number(nil), do: nil
  def format_number(0), do: nil
  def format_number(value), do: Number.Delimit.number_to_delimited(value, precision: 0)

end
