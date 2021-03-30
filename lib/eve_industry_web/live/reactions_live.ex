defmodule EveIndustryWeb.ReactionsLive do
  use EveIndustryWeb, :live_view
  import EveIndustry.Blueprints

  @impl true
  def mount(_params, _session, socket) do
    {:ok, assign(socket, :items, get_items())}
  end

  defp get_items do
    groups = [2402, 2403, 2404]

    by_groups(groups)
  end
end
