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
    rig = :t2
    structure = :azbel

    groups = [2156, 2322, 2510, 2393]

    config = %{
      "blueprint_me" => blueprint_me
    }

    data = calculate(:industry, groups, blueprint_me, batch_size, security, rig, structure)

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

    data = calculate(
      :industry,
      groups,
      String.to_integer(config["blueprint_me"]),
      batch_size,
      String.to_atom(config["security"]),
      String.to_atom(config["rig"]),
      String.to_atom(config["structure"])
    )

    {:ok, assign(
      socket,
      config: config,
      data: data
      )
    }

    {:noreply, assign(socket, config: config, data: data)}

  end

end
