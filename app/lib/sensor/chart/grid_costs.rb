class Sensor::Chart::GridCosts < Sensor::Chart::FinanceBase
  def finance_sensor_name
    :grid_costs
  end

  def source_sensor_names
    return super unless timeframe.short?

    [:grid_import_power]
  end

  # Transform grid_import_power to costs by multiplying with electricity price
  def transform_data(data, _sensor_name)
    return super unless timeframe.short?

    price = get_price(:electricity)
    return data unless price

    data.map { |value| calculate_euro_rate(value, price) }
  end
end
