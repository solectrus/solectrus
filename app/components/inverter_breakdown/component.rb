class InverterBreakdown::Component < ViewComponent::Base
  include BreakdownTable

  def initialize(data:, timeframe:, sensor_name:)
    super()
    @data = data
    @timeframe = timeframe
    @sensor_name = sensor_name
  end

  attr_reader :data, :timeframe, :sensor_name

  # The horizontal table view (and its toggle) is only meaningful when the
  # generation is split across multiple strings. A single inverter keeps the
  # plain segment view without a toggle.
  def breakdown?
    custom_inverter_sensors.any?
  end

  def custom_inverter_sensors
    @custom_inverter_sensors ||= Sensor::Config.custom_inverter_sensors
  end

  # Attach the toggle controller only in breakdown mode; without a table target
  # the controller would raise on connect.
  def wrapper_attributes
    return {} unless breakdown?

    {
      'data-controller' => 'view-toggle',
      'data-view-toggle-key-value' => 'inverterViewMode',
    }
  end

  def no_production?
    data.inverter_power.to_f.zero?
  end

  # Remainder between the total inverter power and the sum of the individual
  # strings (unassigned production).
  def other_sensor
    Sensor::Registry[:inverter_power_difference]
  end

  def other_percent
    data.inverter_power_difference_percent.to_f
  end

  def show_other?
    !data.inverter_power_difference.to_f.zero?
  end

  private

  def breakdown_sensors
    custom_inverter_sensors
  end

  def other_value
    data.inverter_power_difference.to_f
  end
end
