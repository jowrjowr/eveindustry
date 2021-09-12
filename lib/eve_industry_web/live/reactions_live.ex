defmodule EveIndustryWeb.ReactionsLive do
  use EveIndustryWeb, :live_view
  import EveIndustryWeb.Live.Helpers
  import EveIndustry.Reactions

  @impl true
  def mount(_params, _session, socket) do
    # groups (from invGroups)

    # 429: "Composite" - advanced moon materials
    # 712: "Biochemical Material" - booster shit, synth to strong.
    # 4096: "Gas-Phase" - gas phase materials
    # 974: "Hybrid Polymers" - polymer materials
    # 428: "Intermediate Materials" - intermediaries, including alchemy output.
    # 427: raw goo
    # 1136: fuel blocks

    # 7 days athanor: 88
    # 7 days tatara: 125

    config = %{
      industry: :reactions,
      batch_size: 88,
      solar_system_id: 30_002_538,
      blueprint_me: 0,
      blueprint_te: 0,
      security: :lowsec,
      reactions: %{
        rig: :t2,
        structure: :athanor
      }
    }

    reactions = calculate(config)

    intermediary = reaction_group(428, reactions)
    advanced = reaction_group(429, reactions)
    gas_phase = reaction_group(4096, reactions)
    booster = reaction_group(712, reactions)
    polymer = reaction_group(974, reactions)

    socket =
      socket
      |> assign(shopping_list: nil)
      |> assign(intermediary: intermediary)
      |> assign(advanced: advanced)
      |> assign(gas_phase: gas_phase)
      |> assign(booster: booster)
      |> assign(polymer: polymer)

    {:ok, socket}
  end

  @impl true
  def handle_event(_event, %{"form" => form}, socket) do
    config = %{
      industry: :reactions,
      batch_size: 88,
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

    # first level shopping list. intermediary
    shopping_list = shopping_list(everything, form)

    # reduce again

    socket =
      socket
      |> assign(shopping_list: shopping_list)

    {:noreply, socket}
  end

  defp reaction_group(group_id, reactions) do
    reactions
    |> Enum.filter(fn {_type_id, item} ->
      item[:products][:group_id] == group_id
    end)
    |> Map.new()
  end
end
