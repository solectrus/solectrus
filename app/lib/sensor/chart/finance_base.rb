class Sensor::Chart::FinanceBase < Sensor::Chart::Base
  def chart_sensor_names
    [finance_sensor_name]
  end

  # Override unit to always show EUR
  def unit
    @unit ||=
      Sensor::UnitFormatter.format(
        unit: :euro,
        context: timeframe.short? ? :rate : :total,
        scaling: :off,
      )
  end

  # No suggested_max for euro charts - let Chart.js auto-scale
  def suggested_max
    nil
  end

  def permitted?
    ApplicationPolicy.finance_charts?
  end

  protected

  def source_sensor_names
    chart_sensor_names
  end

  def build_chart_data_items
    items = source_chart_data_items
    return items if source_sensor_names == chart_sensor_names

    items.map { |item| item.merge(sensor_name: finance_sensor_name) }
  end

  def source_chart_data_items
    source_sensor_names.map { |name| build_chart_data_item(name) }
  end

  def finance_sensor_name
    raise NotImplementedError, 'Subclasses must implement finance_sensor_name'
  end

  # Get price for a specific type and date
  def get_price(price_type)
    Price.at(name: price_type, date: timeframe.date)
  end

  # Convert W to kW and multiply by price to get EUR/h
  def calculate_euro_rate(watt_value, price)
    return unless watt_value && price

    (watt_value * price).fdiv(1000)
  end

  # Helper to find chart data by sensor name
  def find_chart_data(chart_data_items, sensor_name)
    chart_data_items.find { |item| item[:sensor_name] == sensor_name } ||
      { sensor_name:, labels: [], data: [] }
  end

  # Build dataset structure for finance charts
  def build_dataset(sensor_id, labels, data)
    {
      labels:,
      datasets: [
        {
          id: sensor_id.to_s,
          label: Sensor::Registry[sensor_id].display_name,
          data:,
        }.merge(style_for_sensor(Sensor::Registry[sensor_id])),
      ],
    }
  end
end
