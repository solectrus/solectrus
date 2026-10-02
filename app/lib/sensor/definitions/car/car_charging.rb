class Sensor::Definitions::CarCharging < Sensor::Definitions::Base
  value unit: :watt, category: :consumer

  home_pages :cars

  chart { |timeframe, cars: nil, **| Sensor::Chart::CarCharging.new(timeframe:, cars:) }

  # The chart builds the charged energy from the wallbox sensors and the
  # charging sessions, so the sensor itself never carries a scalar value.
  chart_only

  requires_permission :car
end
