class Sensor::Definitions::CarMileage < Sensor::Definitions::Base
  include Sensor::Definitions::CarNumber

  value unit: :kilometer, range: (0..), category: :car

  color background: 'bg-sensor-wallbox', text: 'text-white dark:text-slate-400'

  icon 'gauge'

  # Arrives with the state of charge, so the same long gaps are normal.
  max_age 2.hours

  # Store the distance driven per day. When the InfluxDB series is sparse
  # (fewer than two readings per day or none at all), the daily diff is
  # derived by linearly interpolating the odometer value at the beginning
  # and end of the day between the surrounding known points. This keeps
  # monthly/weekly/daily breakdowns plausible even across large data gaps,
  # and SUM(daily_diff) equals the total distance between the first and
  # last known odometer reading in any queried range.
  aggregations stored: %i[sum], meta: %i[sum], top10: true, meter: true

  # Distance is the SUM of the daily distances across the period.
  trend

  # The car page gives its cars (see CarSelectable). Without them, the chart
  # shows this car.
  chart do |timeframe, cars: nil, **|
    Sensor::Chart::CarMileage.new(timeframe:, cars: cars || Car.where(id: car_number))
  end

  requires_permission :car
end
