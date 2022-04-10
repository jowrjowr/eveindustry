defmodule EveIndustryWeb.OreLive do
  use EveIndustryWeb, :live_view

  @impl true
  def mount(_params, _session, socket) do
    all_compressed = EveIndustry.Ore.compressed(:lowsec, :four_percent, :t2, :athanor)

    compressed_ice_range = Enum.to_list(28433..28444)
    compressed_gas_range = Enum.to_list(62377..62406)
    compressed_moon_range = Enum.to_list(62454..62515)
    compressed_regular_range = Enum.to_list(62515..62588)

    ice = Enum.filter(all_compressed, fn {type_id, _item} -> type_id in compressed_ice_range end) |> Map.new()
    gas = Enum.filter(all_compressed, fn {type_id, _item} -> type_id in compressed_gas_range end) |> Map.new()
    moon = Enum.filter(all_compressed, fn {type_id, _item} -> type_id in compressed_moon_range end) |> Map.new()
    regular = Enum.filter(all_compressed, fn {type_id, _item} -> type_id in compressed_regular_range end) |> Map.new()

    data = %{
      ice: ice,
      gas: gas,
      moon: moon,
      regular: regular,
      config: %{}
    }

    {:ok, assign(socket, data)}
  end

  @impl true
  def handle_event(_event, %{"config" => config}, socket) do
    all_compressed =
      EveIndustry.Ore.compressed(
        String.to_atom(config["security"]),
        String.to_atom(config["implant"]),
        String.to_atom(config["rig"]),
        String.to_atom(config["structure"])
      )

    compressed_ice_range = Enum.to_list(28433..28444)
    compressed_gas_range = Enum.to_list(62377..62406)
    compressed_moon_range = Enum.to_list(62454..62515)
    compressed_regular_range = Enum.to_list(62515..62588)

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

    moongoo =
      case config["moongoo"] do
        "all" -> "all"
        moongoo -> String.to_integer(moongoo)
      end

    hide_no_sell_volume =
      case config["hide_no_sell_volume"] do
        "true" -> true
        _ -> false
      end

    IO.inspect(hide_no_sell_volume)

    ice =
      all_compressed
      |> Enum.filter(fn {type_id, _item} -> type_id in compressed_ice_range end)
      |> Enum.filter(fn {_, item} -> item[:profitable] == show_profitable end)
      |> Enum.filter(fn {_, item} -> hide_no_volume_logic(hide_no_sell_volume, item[:sell_price]) end)
      |> Map.new()

    gas =
      all_compressed
      |> Enum.filter(fn {type_id, _item} -> type_id in compressed_gas_range end)
      |> Enum.filter(fn {_, item} -> item[:profitable] == show_profitable end)
      |> Enum.filter(fn {_, item} -> hide_no_volume_logic(hide_no_sell_volume, item[:sell_price]) end)
      |> Map.new()

    moon =
      all_compressed
      |> Enum.filter(fn {type_id, _item} -> type_id in compressed_moon_range end)
      |> Enum.filter(fn {_, item} -> item[:profitable] == show_profitable end)
      |> Enum.filter(fn {_, item} -> Enum.member?(item[:yield_types], moongoo) || moongoo == "all" end)
      |> Enum.filter(fn {_, item} -> hide_no_volume_logic(hide_no_sell_volume, item[:sell_price]) end)
      |> Map.new()

    regular =
      all_compressed
      |> Enum.filter(fn {type_id, _item} -> type_id in compressed_regular_range end)
      |> Enum.filter(fn {_, item} -> item[:profitable] == show_profitable end)
      |> Enum.filter(fn {_, item} -> Enum.member?(item[:yield_types], mineral) || mineral == "all" end)
      |> Enum.filter(fn {_, item} -> hide_no_volume_logic(hide_no_sell_volume, item[:sell_price]) end)
      |> Map.new()

    data = %{
      ice: ice,
      gas: gas,
      moon: moon,
      regular: regular,
      config: config
    }

    {:noreply, assign(socket, data)}
  end

  defp hide_no_volume_logic(true, sell_price) when sell_price > 0 do
    true
  end

  defp hide_no_volume_logic(true, _sell_price) do
    false
  end

  defp hide_no_volume_logic(false, _sell_volume) do
    true
  end

  defp fetch_yield(%{yield: yield}, type_id) do
    case Map.get(yield, type_id) do
      nil -> 0
      %{amount: amount} -> Float.round(amount, 2)
    end
  end

  defp select_mineral() do
    [
      All: "all",
      Tritanium: 34,
      Pyerite: 35,
      Isogen: 37,
      Mexallon: 36,
      Nocxium: 38,
      Zydrine: 39,
      Megacyte: 40,
      Morphite: 11399
    ]
  end

  defp select_moongoo() do
    [
      All: "all",
      "atm. gasses": 16634,
      cadmium: 16643,
      caesium: 16647,
      chromium: 16641,
      cobalt: 16640,
      dyspro: 16650,
      "eva. deposits": 16635,
      hafnium: 16648,
      hydrocarbons: 16633,
      mercury: 16646,
      neodynium: 16651,
      platinum: 16644,
      promethium: 16652,
      scandium: 16639,
      silicates: 16636,
      technetium: 16649,
      thulium: 16653,
      titanium: 16638,
      tungsten: 16637,
      vanadium: 16642
    ]
  end

  defp select_structure() do
    [
      Athanor: :athanor,
      Tatara: :tatara,
      Station: :station
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
      Lowsec: :lowsec,
      Nullsec: :nullsec,
      Highsec: :highsec,
      Wormhole: :wormhole
    ]
  end

  defp select_rig() do
    [
      T2: :t2,
      T1: :nullsec,
      None: nil
    ]
  end

  defp format_number(nil), do: nil
  defp format_number(0), do: nil
  defp format_number(value), do: Number.Delimit.number_to_delimited(value, precision: 0)

  defp format_percent(nil), do: nil
  defp format_percent(value), do: Number.Percentage.number_to_percentage(100 * value, precision: 2)

  defp trim_compressed(string), do: String.replace_leading(string, "Compressed ", "")
end
