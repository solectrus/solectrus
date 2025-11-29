class Sensor::Chart::InverterPower < Sensor::Chart::Base
  def initialize(timeframe:, variant: nil)
    super(timeframe:)
    @variant = variant
  end

  attr_reader :variant

  # Override chart_sensor_names to include individual inverters + difference sensor
  def chart_sensor_names
    sensors =
      if stackable?
        # Stacked: individual inverters + difference (calculated automatically)
        [*individual_inverter_sensors, :inverter_power_difference]
      else
        # Show only total inverter power
        [:inverter_power]
      end

    # Add forecast sensors only in non-stacked view (to avoid too many curves)
    if timeframe.day? && !stackable?
      # Add forecast sensors, if they exist
      %i[
        inverter_power_forecast
        inverter_power_forecast_clearsky
      ].each do |sensor_name|
        sensors << sensor_name if Sensor::Config.exists?(sensor_name)
      end
    end

    sensors
  end

  # Override datasets to provide stacked multi-inverter datasets
  def datasets(chart_data_items)
    if stackable?
      # Simple: show all sensors that have data
      chart_data_items.map { |item| build_dataset(item[:sensor_name], item) }
    else
      super # Use base class implementation
    end
  end

  # Check if chart should be stackable (based on old logic)
  def stackable?
    return false unless Sensor::Config.multi_inverter?
    return false unless ApplicationPolicy.multi_inverter?
    return false if individual_inverter_sensors.none?

    # For balance view: never show stacked
    # For inverter view with variant 'split': always show stacked (individual inverters)
    variant == 'split'
  end

  # Get individual inverter sensors (excluding the main inverter_power)
  def individual_inverter_sensors
    @individual_inverter_sensors ||=
      Sensor::Config.custom_inverter_sensors.map(&:name)
  end

  # Enable interpolation for forecast data
  def interpolate?
    true
  end

  private

  def style_for_sensor(sensor)
    if sensor.name == :inverter_power_forecast_clearsky
      {
        borderWidth: 1,
        borderDash: [2, 3], # Dotted line pattern
        fill: false,
        backgroundColor: sensor.color_hex,
      }
    else
      super
    end
  end

  def build_dataset(sensor_name, chart_data)
    sensor = Sensor::Registry[sensor_name]

    dataset = {
      id: sensor.name,
      label: sensor.display_name,
      data: chart_data[:data],
    }

    # Only stack actual inverter power sensors, not forecasts
    dataset[:stack] = 'InverterPower' unless sensor.category == :forecast

    dataset.merge(style_for_sensor(sensor))
  end
end
