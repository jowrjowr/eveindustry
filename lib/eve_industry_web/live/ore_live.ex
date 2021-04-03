defmodule EveIndustryWeb.OreLive do
  use EveIndustryWeb, :live_view

  @impl true
  def mount(_params, _session, socket) do

    data = EveIndustry.Ore.compressed(:lowsec, :four_percent, :t2, :athanor)
    keys = Map.keys(data)

    {:ok, assign(socket, keys: keys, data: data)}
  end

  @impl true
  def handle_event(_event, %{"config" => config}, socket) do

    data =
      EveIndustry.Ore.compressed(
        String.to_atom(config["security"]),
        String.to_atom(config["implant"]),
        String.to_atom(config["rig"]),
        String.to_atom(config["structure"])
      )

    # UI selected filters

    show_profitable =
      case config["show_profitable"] do
        "true" -> true
        _ -> false
      end

    mineral =
      case config["mineral"] do
        "all" -> "all"
        mineral -> String.to_integer(mineral)
      end

    data =
      data
      |> Enum.filter(fn {_, item} -> item[:profitable] == show_profitable end)
      |> Enum.filter(fn {_, item} -> Enum.member?(item[:yield_types], mineral) || mineral == "all" end)
      |> Map.new()

    keys = Map.keys(data)

    {:noreply, assign(socket, keys: keys, data: data)}

  end

  defp fetch_yield(%{yield: yield}, type_id) do

    case Map.get(yield, type_id) do
      nil -> 0
      %{amount: amount} -> Float.round(amount, 2)
    end

  end

  defp select_mineral() do
    [
      "All": "all",
      "Tritanium": 34,
      "Pyerite": 35,
      "Isogen": 37,
      "Mexallon": 36,
      "Nocxium": 38,
      "Zydrine": 39,
      "Megacyte": 40,
      "Morphite": 11399
    ]

  end

  defp select_structure() do

    [
      "Athanor": :athanor,
      "Tatara": :tatara,
      "Station": :station
    ]
  end

  defp select_implant() do

    [
      "4%": :four_percent,
      "I'm poor": :garbage
    ]
  end

  defp select_security() do

    [
      "Lowsec": :lowsec,
      "Nullsec": :nullsec,
      "Highsec": :highsec,
      "Wormhole": :wormhole
    ]
  end

  defp select_rig() do

    [
      "T2": :t2,
      "T1": :nullsec,
      "None": nil
    ]
  end

  defp format_number(nil), do: nil
  defp format_number(0), do: nil
  defp format_number(value), do: Number.Delimit.number_to_delimited(value, precision: 0)

  defp format_percent(nil), do: nil
  defp format_percent(value), do: Number.Percentage.number_to_percentage(100 * value, precision: 2)

  defp trim_compressed(string), do: String.replace_leading(string, "Compressed ", "")

end
