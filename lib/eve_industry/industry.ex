defmodule EveIndustry.Industry do
  alias EveIndustry.{
    Blueprints,
    Bonuses,
    Formulas,
    Prices
  }

  # core temp regulator bp 57516
  # capital version 57524
  # pressurized oxidizers bp 57492
  def calculate(config) do
    industry =
      Blueprints.everything()
      |> Enum.filter(fn item -> item.products != nil end)
      |> Enum.reduce([], fn blueprint, acc ->
        acc ++ [{blueprint.typeID, Blueprints.to_map(blueprint)}]
      end)
      |> Map.new()
      |> Map.new(fn item -> calculate_yields(config, item) end)
      |> Map.new(fn item -> calculate_tax(config, item) end)
      |> Map.new(fn item -> calculate_market_prices(item) end)

    # industry flow, at maximum
    # cap ship -> cap component -> component -> adv reaction -> intermediate reaction -> fuel block
    # 6 levels worst case
    industry = Map.new(industry, fn item -> calculate_industry_prices(item, industry) end)
    industry = Map.new(industry, fn item -> calculate_industry_prices(item, industry) end)
    industry = Map.new(industry, fn item -> calculate_industry_prices(item, industry) end)
    industry = Map.new(industry, fn item -> calculate_industry_prices(item, industry) end)
    industry = Map.new(industry, fn item -> calculate_industry_prices(item, industry) end)
    industry = Map.new(industry, fn item -> calculate_industry_prices(item, industry) end)
    industry = Map.new(industry, fn item -> calculate_industry_prices(item, industry) end)

    # final touches
    industry
    |> Map.new(fn item -> purge_garbage(item) end)
    |> Map.new(fn item -> calculate_margins(item) end)
  end

  defp calculate_margins({type_id, item}) do
    # this is the price from buying components from the market

    buy_price = Prices.buy_price(item.products.type_id)
    sell_price = Prices.sell_price(item.products.type_id)

    sell_margin =
      case {sell_price, item.unit_industry_cost} do
        {0.0, _} -> 0.0
        {_, 0.0} -> 0.0
        {x, y} -> Float.round(x / y, 2)
      end

    buy_margin =
      case {buy_price, item.unit_industry_cost} do
        {0.0, _} -> 0.0
        {_, 0.0} -> 0.0
        {x, y} -> Float.round(x / y, 2)
      end

    item =
      item
      |> Map.put(:sell_margin, sell_margin)
      |> Map.put(:sell_price, sell_price)
      |> Map.put(:buy_margin, buy_margin)
      |> Map.put(:buy_price, buy_price)

    {type_id, item}
  end

  defp purge_garbage({type_id, item}) do
    # this is the price from buying components from the market

    item =
      item
      |> Map.delete(:blueprint)
      |> Map.delete(:unit_tax)

    {type_id, item}
  end

  defp calculate_yields(config, {type_id, item}) do
    batch_size = Map.get(config, :batch_size, 20)
    security = Map.get(config, :security, :lowsec)

    manufacturing_config =
      Map.get(config, :manufacturing, %{
        rig: :t1,
        structure: :azbel
      })

    reactions_config =
      Map.get(config, :reactions, %{
        rig: :t2,
        structure: :athanor
      })

    # reactions are a blueprint with ME0 and TE0, for industry calc purposes.

    {me_bonus, blueprint_me} =
      case item.industry_type do
        :manufacturing ->
          blueprint_me = Map.get(config, :blueprint_me, 0)
          me_bonus = Bonuses.me(:manufacturing, security, manufacturing_config)
          {me_bonus, blueprint_me}

        :reactions ->
          me_bonus = Bonuses.me(:reactions, security, reactions_config)
          {me_bonus, 0}

        _ ->
          {1.0, 0}
      end

    blueprint = item.blueprint
    build_quantity = blueprint.products.quantity * batch_size

    materials =
      blueprint.materials
      |> Enum.reduce([], fn material, acc ->
        material_type_id = material.materialTypeID
        material_industry_type = Blueprints.item_industry_type(material_type_id)

        material_quantity =
          Formulas.material_amount(blueprint_me, me_bonus, material.quantity, batch_size)

        result = %{
          type_id: material_type_id,
          group_id: material.name.groupID,
          name: material.name.typeName,
          quantity: material_quantity,
          industry_type: material_industry_type
        }

        [{material_type_id, result}] ++ acc
      end)
      |> Map.new()

    products = %{
      type_id: blueprint.products.productTypeID,
      name: blueprint.products.name.typeName,
      group_id: blueprint.products.name.groupID,
      quantity: build_quantity
    }

    item =
      item
      |> Map.put(:materials, materials)
      |> Map.put(:products, products)

    {type_id, item}
  end

  defp calculate_tax(config, {type_id, item}) do
    solar_system_id = Map.get(config, :solar_system_id, 30_002_538)
    batch_size = Map.get(config, :batch_size, 20)
    blueprint = item.blueprint

    cost_index = Formulas.cost_index(item.industry_type, solar_system_id)

    build_tax =
      Enum.reduce(blueprint.materials, 0, fn material, acc ->
        tax_quantity = Formulas.material_amount(0, 1.0, material.quantity, batch_size)
        adjusted_price = Prices.adjusted_price(material.materialTypeID)

        material_tax = tax_quantity * adjusted_price * cost_index

        acc + material_tax
      end)

    unit_tax = build_tax / item.products.quantity

    {type_id, Map.put(item, :unit_tax, unit_tax)}
  end

  defp calculate_market_prices({type_id, item}) do
    # this is the price from buying components from the market

    market_cost =
      item.materials
      |> Enum.reduce(0, fn {material_type_id, material}, acc ->
        quantity = material[:quantity]
        sell_price = Prices.sell_price(material_type_id)

        acc + sell_price * quantity
      end)

    unit_market_cost = item.unit_tax + market_cost / item.products.quantity

    {type_id, Map.put(item, :unit_market_cost, unit_market_cost)}
  end

  def calculate_industry_prices({type_id, item}, all_items) do
    # attempt to calculate the build value of an item using previously calculated values

    materials = item.materials

    industry_cost =
      materials
      |> Enum.reduce(0, fn {material_type_id, material}, acc ->
        industry_type = material.industry_type

        material_value =
          case industry_type do
            nil ->
              # buy from market
              Prices.sell_price(material_type_id)

            _ ->
              # build me!
              # these are almost all 1:1 except for some dumb ccp test blueprints
              material_blueprint_type_id =
                material_type_id
                |> Blueprints.blueprint_from_type()
                |> hd()

              industry_cost =
                all_items
                |> Map.get(material_blueprint_type_id, %{})
                |> Map.get(:unit_industry_cost, 0.0)

              industry_cost
          end

        acc + material.quantity * material_value
      end)

    unit_industry_cost = item.unit_tax + industry_cost / item.products.quantity

    {type_id, Map.put(item, :unit_industry_cost, unit_industry_cost)}
  end
end
