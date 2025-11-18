class Sensor::Chart::Savings < Sensor::Chart::FinanceBase
  def chart_sensor_names
    return [:savings] unless timeframe.short?

    %i[
      house_power
      heatpump_power
      wallbox_power
      grid_import_power
      grid_export_power
    ]
  end

  def permitted?
    ApplicationPolicy.finance_charts?
  end

  def build_data
    return super unless timeframe.short?

    electricity_price = get_price(:electricity)
    feed_in_price = get_price(:feed_in)
    return unless electricity_price && feed_in_price

    sensor_data = fetch_sensor_data
    labels = extract_labels(sensor_data)
    data = calculate_data(labels, sensor_data, electricity_price, feed_in_price)

    build_dataset(:savings, labels, data)
  end

  private

  def fetch_sensor_data
    chart_sensor_names.map do |name|
      find_chart_data(build_chart_data_items, name)
    end
  end

  def extract_labels(sensor_data)
    sensor_data.max_by { |item| item[:labels]&.length || 0 }&.dig(:labels) || []
  end

  def calculate_data(labels, sensor_data, electricity_price, feed_in_price)
    labels.each_with_index.map do |_label, index|
      calculate_savings_at_index(
        index,
        sensor_data,
        electricity_price,
        feed_in_price,
      )
    end
  end

  def calculate_savings_at_index(
    index,
    sensor_data,
    electricity_price,
    feed_in_price
  )
    house, heatpump, wallbox, grid_import, grid_export =
      sensor_data.map { |s| s[:data][index] || 0 }

    traditional_costs =
      calculate_euro_rate(house + heatpump + wallbox, electricity_price)
    solar_price =
      calculate_euro_rate(grid_import, electricity_price) -
        calculate_euro_rate(grid_export, feed_in_price)

    traditional_costs - solar_price
  end
end
