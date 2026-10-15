# @label SensorValue
# @logical_path data_display
class SensorValueComponentPreview < ViewComponent::Preview
  # @!group Power Sensors

  def inverter_power_watts
    data = data_example(inverter_power: 750)
    render Sensor::Value::Component.new(data, :inverter_power)
  end

  def inverter_power_kilowatts
    data = data_example(inverter_power: 2500)
    render Sensor::Value::Component.new(data, :inverter_power)
  end

  def inverter_power_megawatts
    data = data_example(inverter_power: 1_500_000)
    render Sensor::Value::Component.new(data, :inverter_power)
  end

  def inverter_power_energy_context
    data = data_example(inverter_power: 15_000)
    render Sensor::Value::Component.new(data, :inverter_power, context: :total)
  end

  # @!group Temperature Sensors

  def case_temperature
    data = data_example(case_temp: 42.7)
    render Sensor::Value::Component.new(data, :case_temp)
  end

  def outdoor_temperature_negative
    data = data_example(outdoor_temp: -5.2)
    render Sensor::Value::Component.new(data, :outdoor_temp)
  end

  # @!group Percentage Sensors

  def autarky_percentage
    data = data_example(autarky: 85.3)
    render Sensor::Value::Component.new(data, :autarky)
  end

  def battery_soc
    data = data_example(battery_soc: 67.8)
    render Sensor::Value::Component.new(data, :battery_soc)
  end

  # @!group Currency Sensors

  def grid_costs
    data = data_example(grid_costs: 123.45)
    render Sensor::Value::Component.new(data, :grid_costs)
  end

  def solar_price
    data = data_example(solar_price: -12.34)
    render Sensor::Value::Component.new(data, :solar_price)
  end

  # @!group Weight Sensors (CO2)

  def co2_reduction_grams
    data = data_example(co2_reduction: 500)
    render Sensor::Value::Component.new(data, :co2_reduction)
  end

  def co2_reduction_kilograms
    data = data_example(co2_reduction: 1500)
    render Sensor::Value::Component.new(data, :co2_reduction)
  end

  def co2_reduction_tons
    data = data_example(co2_reduction: 2_500_000)
    render Sensor::Value::Component.new(data, :co2_reduction)
  end

  # @!group Boolean Sensors

  def wallbox_car_connected_true
    data = data_example(wallbox_car_connected: true)
    render Sensor::Value::Component.new(data, :wallbox_car_connected)
  end

  def wallbox_car_connected_false
    data = data_example(wallbox_car_connected: false)
    render Sensor::Value::Component.new(data, :wallbox_car_connected)
  end

  # @!group String Sensors

  def system_status
    data = data_example(system_status: 'CHARGING')
    render Sensor::Value::Component.new(data, :system_status)
  end

  # @!group Unitless Sensors

  def heatpump_cop
    data = data_example(heatpump_cop: 3.2)
    render Sensor::Value::Component.new(data, :heatpump_cop)
  end

  # @!group Edge Cases

  def zero_value
    data = data_example(inverter_power: 0)
    render Sensor::Value::Component.new(data, :inverter_power)
  end

  def nil_value
    data = data_example(system_status: nil)
    render Sensor::Value::Component.new(data, :system_status)
  end

  def negative_power
    data = data_example(grid_import_power: -1500)
    render Sensor::Value::Component.new(data, :grid_import_power)
  end

  def very_small_decimal
    data = data_example(grid_costs: 0.0001234)
    render Sensor::Value::Component.new(data, :grid_costs)
  end

  def floating_point_precision
    data = data_example(inverter_power: 2999.9999)
    render Sensor::Value::Component.new(data, :inverter_power)
  end

  # @!group Styling

  def with_positive_signal
    data = data_example(inverter_power: 2500)
    render Sensor::Value::Component.new(
             data,
             :inverter_power,
             class: 'text-signal-positive',
           )
  end

  def with_negative_signal
    data = data_example(grid_import_power: 1500)
    render Sensor::Value::Component.new(
             data,
             :grid_import_power,
             class: 'text-signal-negative',
           )
  end

  def with_large_text
    data = data_example(battery_soc: 85.3)
    render Sensor::Value::Component.new(
             data,
             :battery_soc,
             class: 'text-lg font-bold',
           )
  end

  # @!group Negative Values

  def with_negative
    data = data_example(opportunity_costs: 23.45)

    render Sensor::Value::Component.new(data, :opportunity_costs, sign: :negative)
  end

  # @!endgroup

  private

  def data_example(hash)
    Sensor::Data::Single.new(hash, timeframe: Timeframe.day)
  end
end
