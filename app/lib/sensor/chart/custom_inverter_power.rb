class Sensor::Chart::CustomInverterPower < Sensor::Chart::Base
  def initialize(timeframe:, sensor_name:, variant: nil)
    super(timeframe:, variant:)
    @sensor_name = sensor_name
  end

  def chart_sensor_names
    [@sensor_name]
  end
end
