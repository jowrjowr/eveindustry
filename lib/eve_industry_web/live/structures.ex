defmodule EveIndustryWeb.StructuresLive do
  use EveIndustryWeb, :live_view
  import EveIndustryWeb.Live.Helpers
  import EveIndustry.Industry

  @impl true
  def mount(_params, _session, socket) do



    batch_size = 100
    security = :lowsec
    rig = :t2
    structure = :athanor
    #def calculate(job_type, groups, blueprint_me, batch_size \\ 100, security \\ :lowsec, rig \\ :t2, structure \\ :athanor) do

    structures = calculate(:industry, [2156, 2322, 2510, 2393], 8, 1, :lowsec, :t2, :azbel)

    {:ok, assign(
      socket,
      structures: structures
      )
    }

  end

end
