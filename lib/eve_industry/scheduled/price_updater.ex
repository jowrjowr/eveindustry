defmodule EveIndustry.Scheduled.PriceUpdater do
  use Task
  # stolen from https://medium.com/@efexen/periodic-tasks-with-elixir-5d9050bcbdb3

  def start_link(_arg) do
    result = Task.start_link(&poll/0)
    get_price()

    result
  end

  def poll() do

    # time is in minutes
    time = 30
    total_time = time * 60 * 1000

    receive do
    after
      total_time ->
        get_price()
        poll()
    end
  end

  defp get_price() do
    EveIndustry.Prices.process_adjusted_prices()

    region = 10000012
    EveIndustry.Prices.process_esi_prices(region)

    :ok
  end
end
