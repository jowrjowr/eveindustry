defmodule EveIndustryWeb.Live.Helpers do
  def choose_group(%{materials: materials}, target_group) do
    Enum.reduce(materials, [], fn {_type_id, %{group_id: group_id, name: name}}, acc ->
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
      |> Enum.filter(fn {_type_id, %{group_id: group_id}} -> group_id == 1136 end)
      |> Enum.reduce(nil, fn {_, %{name: name, quantity: quantity, type_id: type_id}}, _acc ->
        {name, quantity, type_id}
      end)

    case result do
      nil ->
        %{name: nil, quantity: nil, type_id: nil}

      {name, quantity, type_id} ->
        %{
          name: trim_fuel(name),
          quantity: format_number(quantity),
          type_id: type_id
        }
    end
  end

  def reaction_inputs(%{materials: materials}, index) do
    result =
      materials
      |> Enum.filter(fn {_type_id, %{group_id: group_id}} -> group_id != 1136 end)
      |> Enum.reduce([], fn {_, %{name: name, quantity: quantity, type_id: type_id}}, acc ->
        acc ++ [{name, quantity, type_id}]
      end)
      |> Enum.at(index)

    case result do
      nil ->
        %{name: nil, quantity: nil, type_id: nil}

      {name, quantity, type_id} ->
        %{name: name, quantity: format_number(quantity), type_id: type_id}
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
      Tatara: :tatara,
      Athanor: :athanor,
      Station: :station
    ]
  end

  def select_manufacturing_structure() do
    [
      Azbel: :azbel,
      Raitaru: :raitaru,
      Sotiyo: :sotiyo
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
      Lowsec: :lowsec,
      Nullsec: :nullsec,
      Highsec: :highsec,
      Wormhole: :wormhole
    ]
  end

  def select_rig() do
    [
      T2: :t2,
      T1: :t1,
      None: nil
    ]
  end

  def select_blueprint_me() do
    [
      "1": 1,
      "2": 2,
      "3": 3,
      "4": 4,
      "5": 5,
      "6": 6,
      "7": 7,
      "8": 8,
      "9": 9,
      "10": 10
    ]
  end

  def format_number(nil), do: nil
  def format_number(0), do: nil
  def format_number(value), do: Number.Delimit.number_to_delimited(value, precision: 0)

  def shopping_list(items, form) do
    # what is being built, and how much?

    :ok = EveIndustry.Stockpile.parse()

    total_manifest =
      form
      |> Map.drop(["rig", "security", "structure"])
      |> Enum.filter(fn {_k, v} -> v != "" end)
      |> Enum.map(fn {k, v} -> {String.to_integer(k), String.to_integer(v)} end)
      |> Enum.map(fn {type_id, build_quantity} ->
        blueprint_details = Map.get(items, type_id)

        materials =
          blueprint_details
          |> Map.get(:materials)
          |> Enum.reduce(%{}, fn {material_type_id, material}, acc ->
            result = %{
              name: material.name,
              type_id: material.type_id,
              industry_type: material.industry_type,
              quantity: material.quantity * build_quantity
            }

            Map.put(acc, material_type_id, result)
          end)

        {type_id, materials}
      end)
      |> Enum.reduce(%{}, fn {_, item_manifest}, acc ->
        # this handles the merge and stockpile functions in one go
        Map.merge(acc, item_manifest, &map_merge/3)
      end)
      |> Enum.reduce(%{}, fn {k, data}, acc ->
        # account for the stockpile
        Map.merge(acc, %{k => subtract_stockpile(data)})
      end)
      |> Enum.reduce(%{}, fn {k, data}, acc ->
        # calculate build slots
        slots = build_slots(items, data)
        result = Map.put(data, :slots, slots)

        Map.merge(acc, %{k => result})
      end)

    total_manifest
  end

  defp build_slots(_, %{industry_type: nil}) do
    0.0
  end

  defp build_slots(_, %{quantity: %{purchase: purchase}}) when purchase == 0 do
    0.0
  end

  defp build_slots(items, %{type_id: type_id, quantity: %{purchase: purchase}}) do
    {_, blueprint_data} =
      items
      |> Enum.filter(fn {_k, v} -> v.products.type_id == type_id end)
      |> hd()

    purchase / blueprint_data.products.quantity
  end

  defp map_merge(_key, v1, v2) do
    # zip all this crap together.
    %{name: name, quantity: q1, type_id: type_id, industry_type: industry_type} = v1
    %{quantity: q2} = v2

    %{name: name, type_id: type_id, industry_type: industry_type, quantity: q1 + q2}
  end

  defp subtract_stockpile(%{name: name, quantity: total, type_id: type_id, industry_type: industry_type}) do
    # what needs to be *purchased*

    stockpile =
      case Cachex.get!(:stockpile, type_id) do
        nil ->
          0

        amount ->
          amount
      end

    purchase =
      case total - stockpile do
        amount when amount > 0 ->
          amount

        _ ->
          0
      end

    %{
      name: name,
      type_id: type_id,
      industry_type: industry_type,
      quantity: %{
        total: total,
        stockpile: stockpile,
        purchase: purchase
      }
    }
  end
end
