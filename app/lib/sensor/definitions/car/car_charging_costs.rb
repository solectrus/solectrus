class Sensor::Definitions::CarChargingCosts < Sensor::Definitions::Base
  value unit: :money, category: :economic

  # A charging session belongs to a full day, so now and a day show the cost
  # of the wallbox, and a longer timeframe the charging cost of the sessions
  chart do |timeframe, cars: nil, **|
    if timeframe.short?
      Sensor::Chart::WallboxCosts.new(timeframe:)
    else
      Sensor::Chart::CarSessions.new(timeframe:, cars:, measure: :cost)
    end
  end

  # The chart builds the costs from the wallbox sensors and the charging
  # sessions, so the sensor itself never carries a scalar value.
  chart_only

  requires_permission :car
end
