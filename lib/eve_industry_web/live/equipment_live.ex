defmodule EveIndustryWeb.EquipmentLive do
  use EveIndustryWeb, :live_view
  import EveIndustryWeb.Live.Helpers

  @impl true
  def mount(_params, _session, socket) do
    config = %{
      industry: :manufacturing,
      solar_system_id: 30_002_538,
      batch_size: 5,
      blueprint_me: 10,
      blueprint_te: 20,
      security: :lowsec,
      manufacturing: %{
        rig: :t1,
        structure: :azbel
      },
      reactions: %{
        rig: :t2,
        structure: :tatara
      }
    }

    data = calculate(config)

    {:ok, assign(socket, data)}
  end

  @impl true
  def handle_event(_event, %{"form" => form}, socket) do
    config = %{
      industry: :manufacturing,
      batch_size: 5,
      solar_system_id: 30_002_538,
      blueprint_me: 10,
      blueprint_te: 20,
      security: String.to_atom(form["security"]),
      manufacturing: %{
        rig: String.to_atom(form["rig"]),
        structure: String.to_atom(form["structure"])
      },
      reactions: %{
        rig: String.to_atom(form["rig"]),
        structure: String.to_atom(form["structure"])
      }
    }

    everything = EveIndustry.Industry.calculate(config)
    shopping_list = shopping_list(everything, form)
    data = %{calculate(config) | shopping_list: shopping_list}

    {:noreply, assign(socket, data)}
  end

  defp calculate(config) do
    types = structure_types()

    t2_fighter_types = Map.get(types, :t2_fighter_types)
    t2_module_types = Map.get(types, :t2_module_types)
    t1_fighter_types = Map.get(types, :t1_fighter_types)
    t1_module_types = Map.get(types, :t1_module_types)
    ammo_types = Map.get(types, :ammo_types)
    burst_projector_types = Map.get(types, :burst_projector_types)
    service_module_types = Map.get(types, :service_module_types)

    items =
      config
      |> EveIndustry.Industry.calculate()
      |> Enum.filter(fn {_type_id, %{name: x}} -> String.starts_with?(x, "Standup") end)
      |> Enum.filter(fn {_type_id, %{name: x}} -> !String.starts_with?(x, "Standup M-Set") end)
      |> Enum.filter(fn {_type_id, %{name: x}} -> !String.starts_with?(x, "Standup L-Set") end)
      |> Enum.filter(fn {_type_id, %{name: x}} -> !String.starts_with?(x, "Standup XL-Set") end)

    t2_fighters = Enum.filter(items, fn {_type_id, %{type_id: x}} -> x in t2_fighter_types end) |> Map.new()
    t1_fighters = Enum.filter(items, fn {_type_id, %{type_id: x}} -> x in t1_fighter_types end) |> Map.new()
    service_modules = Enum.filter(items, fn {_type_id, %{type_id: x}} -> x in service_module_types end) |> Map.new()
    ammo = Enum.filter(items, fn {_type_id, %{type_id: x}} -> x in ammo_types end) |> Map.new()
    burst_projectors = Enum.filter(items, fn {_type_id, %{type_id: x}} -> x in burst_projector_types end) |> Map.new()
    t1_modules = Enum.filter(items, fn {_type_id, %{type_id: x}} -> x in t1_module_types end) |> Map.new()
    t2_modules = Enum.filter(items, fn {_type_id, %{type_id: x}} -> x in t2_module_types end) |> Map.new()

    %{
      t2_fighters: t2_fighters,
      t1_fighters: t1_fighters,
      t1_modules: t1_modules,
      t2_modules: t2_modules,
      service_modules: service_modules,
      burst_projectors: burst_projectors,
      ammo: ammo,
      shopping_list: nil
    }
  end

  defp structure_types() do
    t2_fighter_types = [
      47217,
      47220,
      47239,
      47229,
      47212,
      47248,
      47244,
      47215,
      47242,
      47231,
      47225,
      47214,
      47246,
      47221,
      47237,
      47238,
      47223,
      47240,
      47227,
      47218,
      47240
    ]

    t1_fighter_types = [
      47245,
      47209,
      47210,
      47213,
      47247,
      47211,
      47208,
      47236,
      47230,
      47226,
      47222,
      47241,
      47243,
      47233,
      47232,
      47224,
      47228,
      47219,
      47216,
      47234,
      47235
    ]

    service_module_types = [
      37022,
      45541,
      43925,
      45551,
      43928,
      43927,
      43926,
      37023,
      43929,
      37034,
      45540,
      37032,
      45542
    ]

    ammo_types = [63196, 37834, 37859, 37855, 37857, 47337, 37853, 37852, 37836, 37856, 37833, 37835, 37858]
    burst_projector_types = [47107, 47111, 47109, 47110, 47112, 47113, 47114, 37030]

    t1_module_types = [
      37041,
      37066,
      37541,
      37029,
      37043,
      37060,
      47354,
      37008,
      47361,
      37087,
      37028,
      37047,
      37081,
      37048,
      37045,
      47357,
      37044,
      37020,
      37080,
      37083
    ]

    t2_module_types = [
      47322,
      47324,
      47326,
      47328,
      47331,
      47333,
      47335,
      47339,
      47341,
      47343,
      47345,
      47346,
      47349,
      47350,
      47355,
      47359,
      47363,
      47365,
      47367,
      47369
    ]

    %{
      t2_fighter_types: t2_fighter_types,
      t2_module_types: t2_module_types,
      t1_fighter_types: t1_fighter_types,
      t1_module_types: t1_module_types,
      ammo_types: ammo_types,
      burst_projector_types: burst_projector_types,
      service_module_types: service_module_types
    }
  end
end
