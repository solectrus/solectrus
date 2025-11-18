class Sensor::Chart::GridRevenue < Sensor::Chart::FinanceBase
  def chart_sensor_names
    timeframe.short? ? [:grid_export_power] : [:grid_revenue]
  end

  def permitted?
    ApplicationPolicy.finance_charts?
  end

  # Transform grid_export_power to revenue by multiplying with feed-in price
  def transform_data(data, _sensor_name)
    return super unless timeframe.short?

    price = get_price(:feed_in)
    return data unless price

    data.map { |value| calculate_euro_rate(value, price) }
  end
end
