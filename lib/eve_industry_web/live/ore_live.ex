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

    show_profitable =
      case config["show_profitable"] do
        "true" -> true
        _ -> false
      end

    data =
      EveIndustry.Ore.compressed(
        String.to_atom(config["security"]),
        String.to_atom(config["implant"]),
        String.to_atom(config["rig"]),
        String.to_atom(config["structure"])
      )

    # filter for profitability

    data =
      data
      |> Enum.filter(fn {_, item} -> item[:profitable] == show_profitable end)
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
