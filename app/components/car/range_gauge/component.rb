# The battery of the car as a gauge: an arc of 240 degrees from 0 to the
# maximum range, filled to the state of charge. The remaining range sits in
# the center. Each value loads its own chart. The block of the component
# stands right above the arc.
class Car::RangeGauge::Component < ViewComponent::Base
  include CarChartLink

  # The arc around (200, 175) with a radius of 150, open at the bottom
  ARC = 'M 70 250 A 150 150 0 1 1 330 250'.freeze
  public_constant :ARC

  # `live` holds the values of one car (see Car::Balance::Live)
  def initialize(live:, timeframe:)
    super()
    @live = live
    @timeframe = timeframe
  end

  attr_reader :live, :timeframe

  def soc
    live.soc&.clamp(0, 100)
  end

  delegate :range, :max_range, to: :live

  # The sensor of this car with the given role, for its chart and its format
  def sensor_name(role)
    Sensor::Cars.sensor_name(role, live.car.id)
  end

  # The fill of the arc in percent of its length, without a trailing ".0"
  def fill_percent
    format('%g', soc.round(1))
  end

  # The color of the arc (:stroke) and of the badge (:bg), like the battery
  # colors of the sensor: red up to 5%, amber up to 20%, then the battery
  # color. The class names stay literal, so Tailwind finds them.
  LEVEL_CLASSES = {
    critical: { stroke: 'stroke-signal-negative', bg: 'bg-signal-negative' },
    low: { stroke: 'stroke-signal-warning', bg: 'bg-signal-warning' },
    good: { stroke: 'stroke-sensor-battery', bg: 'bg-sensor-battery' },
  }.freeze
  private_constant :LEVEL_CLASSES

  def level_class(property)
    level =
      if soc <= 5
        :critical
      elsif soc <= 20
        :low
      else
        :good
      end

    LEVEL_CLASSES.dig(level, property)
  end
end
