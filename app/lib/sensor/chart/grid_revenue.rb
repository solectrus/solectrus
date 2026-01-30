class Sensor::Chart::GridRevenue < Sensor::Chart::FinanceBase
  def finance_sensor_name
    :grid_revenue
  end

  def source_sensor_names
    return super unless timeframe.short?

    [:grid_export_power]
  end

  # Transform grid_export_power to revenue by multiplying with feed-in price
  def transform_data(data, _sensor_name)
    return super unless timeframe.short?

    price = get_price(:feed_in)
    return data unless price

    data.map { |value| calculate_euro_rate(value, price) }
  end
end
