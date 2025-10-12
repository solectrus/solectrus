class SensorValue::ComponentPreview < ViewComponent::Preview
  # @!group Power Sensors

  def inverter_power_watts
    data = data_example(inverter_power: 750)
    render SensorValue::Component.new(data, :inverter_power)
  end

  def inverter_power_kilowatts
    data = data_example(inverter_power: 2500)
    render SensorValue::Component.new(data, :inverter_power)
  end

  def inverter_power_megawatts
    data = data_example(inverter_power: 1_500_000)
    render SensorValue::Component.new(data, :inverter_power)
  end

  def inverter_power_energy_context
    data = data_example(inverter_power: 15_000)
    render SensorValue::Component.new(data, :inverter_power, context: :energy)
  end

  # @!group Temperature Sensors

  def case_temperature
    data = data_example(case_temp: 42.7)
    render SensorValue::Component.new(data, :case_temp)
  end

  def outdoor_temperature_negative
    data = data_example(outdoor_temp: -5.2)
    render SensorValue::Component.new(data, :outdoor_temp)
  end

  # @!group Percentage Sensors

  def autarky_percentage
    data = data_example(autarky: 85.3)
    render SensorValue::Component.new(data, :autarky)
  end

  def battery_soc
    data = data_example(battery_soc: 67.8)
    render SensorValue::Component.new(data, :battery_soc)
  end

  # @!group Currency Sensors

  def grid_costs
    data = data_example(grid_costs: 123.45)
    render SensorValue::Component.new(data, :grid_costs)
  end

  def electricity_price
    data = data_example(electricity_price: 0.30123)
    render SensorValue::Component.new(data, :electricity_price)
  end

  # @!group Weight Sensors (CO2)

  def co2_reduction_grams
    data = data_example(co2_reduction: 500)
    render SensorValue::Component.new(data, :co2_reduction)
  end

  def co2_reduction_kilograms
    data = data_example(co2_reduction: 1500)
    render SensorValue::Component.new(data, :co2_reduction)
  end

  def co2_reduction_tons
    data = data_example(co2_reduction: 2_500_000)
    render SensorValue::Component.new(data, :co2_reduction)
  end

  # @!group Boolean Sensors

  def wallbox_car_connected_true
    data = data_example(wallbox_car_connected: true)
    render SensorValue::Component.new(data, :wallbox_car_connected)
  end

  def wallbox_car_connected_false
    data = data_example(wallbox_car_connected: false)
    render SensorValue::Component.new(data, :wallbox_car_connected)
  end

  # @!group String Sensors

  def system_status
    data = data_example(system_status: 'CHARGING')
    render SensorValue::Component.new(data, :system_status)
  end

  # @!group Unitless Sensors

  def heatpump_cop
    data = data_example(heatpump_cop: 3.2)
    render SensorValue::Component.new(data, :heatpump_cop)
  end

  # @!group Edge Cases

  def zero_value
    data = data_example(inverter_power: 0)
    render SensorValue::Component.new(data, :inverter_power)
  end

  def nil_value
    data = data_example(system_status: nil)
    render SensorValue::Component.new(data, :system_status)
  end

  def negative_power
    data = data_example(grid_import_power: -1500)
    render SensorValue::Component.new(data, :grid_import_power)
  end

  def very_small_decimal
    data = data_example(electricity_price: 0.0001234)
    render SensorValue::Component.new(data, :electricity_price)
  end

  def floating_point_precision
    data = data_example(inverter_power: 2999.9999)
    render SensorValue::Component.new(data, :inverter_power)
  end

  # @!group Styling Examples

  def with_custom_css_classes
    data = data_example(inverter_power: 2500)
    render SensorValue::Component.new(
             data,
             :inverter_power,
             class: 'text-green-600 font-bold text-lg',
           )
  end

  # @!group Examples with Custom Styling

  def with_green_styling
    data = data_example(inverter_power: 2500)
    render SensorValue::Component.new(
             data,
             :inverter_power,
             class: 'text-green-600',
           )
  end

  def with_red_styling
    data = data_example(grid_import_power: 1500)
    render SensorValue::Component.new(
             data,
             :grid_import_power,
             class: 'text-red-600',
           )
  end

  def with_large_text
    data = data_example(battery_soc: 85.3)
    render SensorValue::Component.new(
             data,
             :battery_soc,
             class: 'text-lg font-bold text-blue-600',
           )
  end

  # @!group Negative Values

  def with_negative
    data = data_example(opportunity_costs: 23.45)

    render SensorValue::Component.new(data, :opportunity_costs, sign: :negative)
  end

  private

  def data_example(hash)
    Sensor::Data::Single.new(hash, timeframe: Timeframe.day)
  end
end
