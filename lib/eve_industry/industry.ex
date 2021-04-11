defmodule EveIndustry.Industry do
  alias EveIndustry.Formulas
  alias EveIndustry.Blueprints
  alias EveIndustry.Bonuses

  def calculate(job_type, groups, blueprint_me, batch_size \\ 100, security \\ :lowsec, rig \\ :t2, structure \\ :athanor) do

    solar_system_id = 30002538

    config = %{
      solar_system_id: solar_system_id,
      job_type: job_type,
      blueprint_me: blueprint_me,
      batch_size: batch_size,
      security: security,
      rig: rig,
      structure: structure
    }

    groups
    |> Blueprints.by_groups()
    |> Enum.reduce([], fn item, acc -> acc ++ [{item.typeID, calculate_details(item, config)}] end)
    |> Map.new()

  end

  def calculate_single(job_type, type_id, blueprint_me, batch_size \\ 100, security \\ :lowsec, rig \\ :t2, structure \\ :athanor) do

    solar_system_id = 30002538

    config = %{
      solar_system_id: solar_system_id,
      job_type: job_type,
      blueprint_me: blueprint_me,
      batch_size: batch_size,
      security: security,
      rig: rig,
      structure: structure
    }

    [ Blueprints.single(type_id) ]
      |> Enum.reduce([], fn item, acc -> acc ++ [{item.typeID, calculate_details(item, config)}] end)
      |> Map.new()

  end


  defp calculate_details(
    data,
    config = %{
      job_type: job_type,
      blueprint_me: blueprint_me,
      batch_size: batch_size,
      security: security,
      rig: rig,
      structure: structure,
      solar_system_id: solar_system_id
    }
    ) do

    materials =
      data.materials
      |> Enum.reduce([], fn material, acc -> material_details(acc, material, config) end)
      |> Map.new()

    build_quantity = data.products.quantity * batch_size

    cost_index = Formulas.cost_index(job_type, solar_system_id)

    batch_tax =
      materials
      |> Enum.reduce(0, fn {type_id, materials}, acc ->
        taxed_quantity = materials[:tax_quantity]
        adjusted_price = materials[:adjusted_price]

        acc + taxed_quantity * adjusted_price * cost_index
      end)

    unit_tax = batch_tax / build_quantity


    calculate_unit_value =
      Enum.reduce(materials, true, fn {type_id, _materials}, acc ->
        acc && Cachex.get!(:min_sell_price, type_id) != nil
      end)

    unit_material_price =
      case calculate_unit_value do
        false -> 0
        true ->
          Enum.reduce(materials, 0, fn {type_id, materials}, acc ->
            quantity = materials[:quantity]
            acc + Cachex.get!(:min_sell_price, type_id) * quantity / build_quantity
          end)
      end
    unit_market_price = unit_material_price + unit_tax

    unit_build_price =
      materials
      |> Enum.reduce(0, fn {type_id, materials}, acc ->
        quantity = materials[:quantity]
        component_build_price = materials[:unit_build_price]

        acc + component_build_price * quantity / build_quantity
      end)
    unit_build_price = unit_build_price + unit_tax

    sell_price =
      case Cachex.get!(:min_sell_price, data.products.productTypeID) do
        nil -> 0
        x -> Float.round(x, 2)
      end

    buy_price =
      case Cachex.get!(:max_buy_price, data.products.productTypeID) do
        nil -> 0
        x -> Float.round(x, 2)
      end

    sell_margin =
      case sell_price do
        0 -> 0
        _ -> Float.round(unit_market_price / sell_price, 4)
      end

    buy_margin =
      case buy_price do
        0 -> 0
        _ -> Float.round(unit_market_price / buy_price, 4)
      end

    profitable = sell_margin > 1 || buy_margin > 1

    products = %{
      type_id: data.products.productTypeID,
      name: data.products.name.typeName,
      group_id: data.products.name.groupID,
      quantity: build_quantity,
      sell_price: sell_price,
      buy_price: buy_price,
    }

    %{
      type_id: data.typeID,
      name: data.typeName,
      group_id: data.groupID,
      market_group_id: data.marketGroupID,
      materials: materials,
      unit_market_price: unit_market_price,
      unit_build_price: unit_build_price,
      batch_tax: batch_tax,
      products: products,
      profitable: profitable
    }

  end



  defp material_details(acc, material, %{
    job_type: job_type,
    batch_size: batch_size,
    security: security,
    blueprint_me: blueprint_me,
    rig: rig,
    structure: structure,
    solar_system_id: solar_system_id
  }) do


    me_bonus = Bonuses.me_bonuses(job_type, structure, security, rig) * (1 - blueprint_me / 100)

    type_id = material.materialTypeID
    blueprint_type_id = Blueprints.blueprint_from_type(type_id)

    quantity = Formulas.material_amount(0, me_bonus, material.quantity, batch_size)
    tax_quantity = Formulas.material_amount(0, 1, material.quantity, batch_size)

    material_sell_price =
      case Cachex.get!(:min_sell_price, type_id) do
        nil -> 0
        x -> Float.round(x, 2)
      end

    adjusted_price =
      case Cachex.get!(:adjusted_price, type_id) do
        nil -> 0
        price -> price
      end

    # calculate build cost of the single item
    # this is explicitly recursive

    unit_build_price =
      case blueprint_type_id do
        nil ->
          # this item has to be bought from the market
          material_sell_price
        _ ->
          # build the component from parts, use that price.

          # hardcoding assumptions for component production purposes
          batch_size = 100
          blueprint_me = 10

          result = calculate_single(job_type, blueprint_type_id, blueprint_me, batch_size, security, rig, structure)
          result[blueprint_type_id][:unit_market_price]
      end

    result = %{
      type_id: type_id,
      group_id: material.name.groupID,
      name: material.name.typeName,
      quantity: quantity,
      tax_quantity: tax_quantity,
      blueprint_type_id: blueprint_type_id,
      unit_build_price: unit_build_price,
      unit_market_price: material_sell_price,
      adjusted_price: adjusted_price
    }
    acc ++ [{ material.materialTypeID, result}]
  end
end
