defmodule EveIndustryWeb.ComponentsLive do
  use EveIndustryWeb, :live_view
  import EveIndustryWeb.Live.Helpers

  @impl true
  def mount(_params, _session, socket) do
    config = %{
      industry: :manufacturing,
      solar_system_id: 30_002_538,
      batch_size: 20,
      blueprint_me: 10,
      blueprint_te: 20,
      security: :lowsec,
      manufacturing: %{
        rig: :t1,
        structure: :azbel
      }
    }

    # group ids
    # structure: 447
    # standard cap components: 915

    market_groups = [1913, 2770, 1592, 1593, 1594, 1595, 796, 1592, 1593, 1594, 1595]

    components =
      config
      |> EveIndustry.Industry.calculate()
      |> Enum.filter(fn {_type_id, %{market_group_id: x}} -> x in market_groups end)
      |> Map.new()

    structure = group_filter(components, 536)
    standard_capital = group_filter(components, 873)
    t2 = group_filter(components, 334)
    shopping_list = nil

    data = %{
      structure: structure,
      standard_capital: standard_capital,
      t2: t2,
      shopping_list: shopping_list
    }

    {:ok, assign(socket, data)}
  end

  @impl true
  def handle_event(_event, %{"form" => form}, socket) do
    config = %{
      industry: :manufacturing,
      batch_size: 20,
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

    # group ids
    # structure: 447
    # standard capital: 873

    everything = EveIndustry.Industry.calculate(config)

    structure = group_filter(everything, 536)
    standard_capital = group_filter(everything, 873)

    shopping_list = shopping_list(everything, form)

    {:noreply,
     assign(socket,
       structure: structure,
       standard_capital: standard_capital,
       shopping_list: shopping_list
     )}
  end

  defp group_filter(map, group_id) do
    Enum.filter(map, fn {_type_id, item} ->
      item[:products][:group_id] == group_id
    end)
    |> Map.new()
  end
end
