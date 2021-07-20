defmodule EveIndustryWeb.StructuresLive do
  use EveIndustryWeb, :live_view
  import EveIndustryWeb.Live.Helpers
  import EveIndustry.Industry

  @impl true
  def mount(_params, _session, socket) do

    # sensible build defaults

    blueprint_me = 8
    batch_size = 1
    security = :lowsec
    rig = :t1
    structure = :azbel

    #groups = [2156, 2322, 2510, 2393]
    groups = [1592, 1593, 1594, 1595]

    config = %{
      batch_size: batch_size,
      blueprint_groups: groups,
      security: security,
      manufacturing: %{
        rig: rig,
        structure: structure,
        blueprint_me: blueprint_me
      },
      reactions: %{
        rig: :t2,
        structure: :athanor
      }
    }
    # config = %{batch_size: 100, blueprint_groups: [1592], security: :lowsec, manufacturing: %{ rig: :t1, structure: :azbel, blueprint_me: 10}}
    # 46213 ferrogel reaction
    # 4316 hydrogen fuel block bp

    data = calculate(config)

    {:ok, assign(
      socket,
      config: config,
      data: data
      )
    }

  end

  @impl true
  def handle_event(event, form, socket) do


    IO.inspect(event)
    IO.inspect(form)

    config = %{}

    groups = [2156, 2322, 2510, 2393]

    batch_size = 1

    # data = calculate(
    #   :industry,
    #   groups,
    #   String.to_integer(config["blueprint_me"]),
    #   batch_size,
    #   String.to_atom(config["security"]),
    #   String.to_atom(config["rig"]),
    #   String.to_atom(config["structure"])
    # )

    {:ok, assign(
      socket,
      config: config,
      data: 1 #data
      )
    }

    {:noreply, assign(socket, config: config, data: 1)}

  end

end
