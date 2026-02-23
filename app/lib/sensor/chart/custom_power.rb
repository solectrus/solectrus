class Sensor::Chart::CustomPower < Sensor::Chart::PowerSplitterBase
  def initialize(timeframe:, sensor_name:, variant: nil)
    super(timeframe:, variant:)
    @sensor_name = sensor_name
  end

  def color_class(_sensor)
    'bg-sensor-house'
  end

  private

  def base_sensor_name
    @sensor_name
  end

  def grid_sensor_name
    :"#{@sensor_name}_grid"
  end

  def pv_sensor_name
    :"#{@sensor_name}_pv"
  end
end
