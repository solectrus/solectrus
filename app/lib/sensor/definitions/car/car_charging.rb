class Sensor::Definitions::CarCharging < Sensor::Definitions::Base
  include Sensor::Definitions::CarPageChart

  value unit: :watt, category: :consumer

  # A charging session belongs to a full day, so now and a day show the power
  # curve of the wallbox, and a longer timeframe the charged energy of the
  # sessions. The chart builds it from the wallbox sensors and the charging
  # sessions, so the sensor itself never carries a scalar value.
  chart do |timeframe, cars: nil, **|
    if timeframe.short?
      Sensor::Chart::CarChargingPower.new(timeframe:)
    else
      Sensor::Chart::CarSessions.new(timeframe:, cars:, measure: :energy)
    end
  end
end
