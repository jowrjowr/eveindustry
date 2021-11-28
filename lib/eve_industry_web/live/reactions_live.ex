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
    # 7 days tatara: 123

    config = %{
      industry: :reactions,
      batch_size: 122,
      solar_system_id: 30_002_538,
      blueprint_me: 0,
      blueprint_te: 0,
      security: :lowsec,
      reactions: %{
        rig: :t2,
        structure: :tatara
      }
    }

    reactions = calculate(config)

    reactions = Enum.filter(reactions, fn {_type_id, %{name: name}} -> String.contains?(name, "Unrefined") == false end)

    intermediary = reaction_group(428, reactions)
    advanced = reaction_group(429, reactions)
    gas_phase = reaction_group(4096, reactions)
    booster = reaction_group(712, reactions)
    polymer = reaction_group(974, reactions)

    # alchemy takes twice as long as every other reaction. keeping same time scale.

    alchemy_batch_size = floor(config.batch_size / 2)

    config = %{config | batch_size: alchemy_batch_size}

    reactions = calculate(config)
    alchemy = calculate_alchemy(reactions)

    data = %{
      shopping_list: nil,
      alchemy: alchemy,
      intermediary: intermediary,
      advanced: advanced,
      gas_phase: gas_phase,
      booster: booster,
      polymer: polymer
    }

    socket = assign(socket, data)

    {:ok, socket}
  end

  @impl true
  def handle_event(_event, %{"form" => form}, socket) do
    config = %{
      industry: :reactions,
      batch_size: 122,
      solar_system_id: 30_002_538,
      blueprint_me: 0,
      blueprint_te: 0,
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

    everything_except_alchemy = EveIndustry.Industry.calculate(config)

    alchemy_batch_size = floor(config.batch_size / 2)
    config = %{config | batch_size: alchemy_batch_size}

    alchemy =
      config
      |> calculate()
      |> Enum.filter(fn {_type_id, %{name: name}} -> String.contains?(name, "Unrefined") == true end)
      |> Map.new()

    everything = Map.merge(everything_except_alchemy, alchemy)

    # first level shopping list. intermediary
    shopping_list = shopping_list(everything, form)

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
