class Sensor::Chart::TotalCosts < Sensor::Chart::FinanceBase
  def chart_sensor_names
    return [:total_costs] unless timeframe.short?

    %i[grid_import_power inverter_power grid_export_power]
  end

  def build_data
    return super unless timeframe.short?

    electricity_price = get_price(:electricity)
    return unless electricity_price

    feed_in_price = get_price(:feed_in)
    return unless feed_in_price

    sensor_data = fetch_sensor_data
    labels = extract_labels(sensor_data)
    data = calculate_data(labels, sensor_data, electricity_price, feed_in_price)

    build_dataset(:total_costs, labels, data)
  end

  private

  def fetch_sensor_data
    {
      grid_import: find_chart_data(build_chart_data_items, :grid_import_power),
      inverter: find_chart_data(build_chart_data_items, :inverter_power),
      grid_export: find_chart_data(build_chart_data_items, :grid_export_power),
    }
  end

  def extract_labels(sensor_data)
    [
      sensor_data[:grid_import],
      sensor_data[:inverter],
      sensor_data[:grid_export],
    ].max_by { |item| item[:labels]&.length || 0 }&.dig(:labels) || []
  end

  def calculate_data(labels, sensor_data, electricity_price, feed_in_price)
    labels.each_with_index.map do |_label, index|
      calculate_total_cost_at_index(
        index,
        sensor_data,
        electricity_price,
        feed_in_price,
      )
    end
  end

  # Uses the calculation logic from Sensor::Definitions::TotalCosts
  def calculate_total_cost_at_index(
    index,
    sensor_data,
    electricity_price,
    feed_in_price
  )
    grid_costs =
      calculate_euro_rate(
        sensor_data[:grid_import][:data][index] || 0,
        electricity_price,
      )

    # Calculate opportunity costs: self_consumption * feed_in_price
    inverter = sensor_data[:inverter][:data][index] || 0
    grid_export = sensor_data[:grid_export][:data][index] || 0
    self_consumption = [inverter - grid_export, 0].max
    opportunity_costs = calculate_euro_rate(self_consumption, feed_in_price)

    # Use the sensor definition's calculation logic
    Sensor::Registry[:total_costs].calculate(grid_costs:, opportunity_costs:)
  end
end
