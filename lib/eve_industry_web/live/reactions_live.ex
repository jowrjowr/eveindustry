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
      solar_system_id: 30002538,
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

    {:ok, assign(
      socket,
      intermediary: intermediary,
      advanced: advanced,
      gas_phase: gas_phase,
      booster: booster,
      polymer: polymer
      )
    }
  end

  @impl true
  def handle_event(event, %{"form" => form}, socket) do

    IO.inspect(event)

    config = %{
      industry: :reactions,
      batch_size: 88,
      solar_system_id: 30002538,
      blueprint_me: 0,
      blueprint_te: 0,
      security: String.to_atom(Map.get(form, "security")),
      reactions: %{
        rig: String.to_atom(Map.get(form, "rig")),
        structure: String.to_atom(Map.get(form, "structure"))
      }
    }

    build =
      form
      |> Map.drop(["rig", "security", "structure"])
      |> Map.new(fn {type_id, quantity} -> build_input_transform(type_id, quantity) end)

    shopping_list = EveIndustry.Industry.shopping_list(config, build)

    {:noreply, assign(socket, shopping_list: shopping_list)}

  end

  defp build_input_transform(type_id, "") do
    type_id = String.to_integer(type_id)

    {type_id, 0}
  end

  defp build_input_transform(type_id, quantity) do
    type_id = String.to_integer(type_id)
    quantity = String.to_integer(quantity)

    {type_id, quantity}
  end

  defp reaction_group(group_id, reactions) do
    reactions
      |> Enum.filter(fn {_type_id, item} ->
        item[:products][:group_id] == group_id
      end)
      |> Map.new()
  end

end
