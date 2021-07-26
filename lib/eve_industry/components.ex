defmodule EveIndustry.Components do
  def calculate(config) do
    # 1913 - structure groups
    # 2770 - general components
    # [1592, 1593, 1594, 1595] - advanced components
    # 796 - capital

    market_groups = [1913, 2770, 1592, 1593, 1594, 1595, 796]

    components =
      config
      |> EveIndustry.Industry.calculate()
      |> Enum.filter(fn {_type_id, %{market_group_id: x}} -> x in market_groups end)
      |> Map.new()

    components
  end
end
