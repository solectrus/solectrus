class Sensor::Definitions::CarChargingCosts < Sensor::Definitions::Base
  include Sensor::Definitions::CarPageChart

  value unit: :money, category: :economic

  # A charging session belongs to a full day, so now and a day show the cost
  # of the wallbox for the selection (see Sensor::Chart::CarChargingCosts),
  # and a longer timeframe the charging cost of the sessions.
  # The chart builds it from the wallbox sensors and the charging sessions, so
  # the sensor itself never carries a scalar value.
  chart do |timeframe, cars: nil, guest: false, **|
    if timeframe.short?
      Sensor::Chart::CarChargingCosts.new(timeframe:, cars:, guest:)
    else
      Sensor::Chart::CarSessions.new(timeframe:, cars:, guest:, measure: :cost)
    end
  end

  trend
end
