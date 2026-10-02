class Sensor::Definitions::CarChargingCosts < Sensor::Definitions::Base
  value unit: :money, category: :economic

  chart { |timeframe, cars: nil, **| Sensor::Chart::CarChargingCosts.new(timeframe:, cars:) }

  # The chart builds the costs from the wallbox sensors and the charging
  # sessions, so the sensor itself never carries a scalar value.
  chart_only

  requires_permission :car
end
