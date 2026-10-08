class Sensor::Definitions::CarOdometer < Sensor::Definitions::Base
  include Sensor::Definitions::CarNumber

  value unit: :kilometer, range: (0..), category: :car

  color background: 'bg-sensor-wallbox', text: 'text-white dark:text-slate-400'

  icon 'gauge'

  # A car reports a change of its state, often only while it is online,
  # so the value holds until the next reading
  state

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

  requires_permission :car
end
