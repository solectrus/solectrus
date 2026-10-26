class Sensor::Definitions::CarCharging < Sensor::Definitions::Base
  include Sensor::Definitions::CarPageChart

  value unit: :watt, category: :consumer

  # The charged energy of the sessions. A charging session belongs to a full
  # day, so now and a day have no chart, but the timeline of the day (see
  # Car::Section.charts?). The chart builds it from the charging sessions, so
  # the sensor itself never carries a scalar value.
  chart do |timeframe, cars: nil, guest: false, **|
    Sensor::Chart::CarSessions.new(timeframe:, cars:, guest:, measure: :energy) unless timeframe.short?
  end

  trend
end
