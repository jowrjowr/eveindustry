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

    batch_size = 100
    security = :lowsec
    rig = :t2
    structure = :athanor

    intermediary = reaction_group(428, batch_size, security, rig, structure)
    advanced = reaction_group(429, batch_size, security, rig, structure)
    gas_phase = reaction_group(4096, batch_size, security, rig, structure)
    booster = reaction_group(712, batch_size, security, rig, structure)
    polymer = reaction_group(974, batch_size, security, rig, structure)

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

  defp reaction_group(group_id, batch_size, security, rig, structure) do
    calculate(batch_size, security, rig, structure)
      |> Enum.filter(fn {type_id, item} ->
        item[:products][:group_id] == group_id
      end)
      |> Map.new()
  end
end
