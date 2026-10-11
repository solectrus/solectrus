class Sensor::Definitions::CarOdometer < Sensor::Definitions::Base
  include Sensor::Definitions::CarNumber

  value unit: :kilometer, range: (0..), category: :car

  color background: 'bg-sensor-wallbox', text: 'text-white dark:text-slate-400'

  icon 'gauge'

  # A car reports a change of its state, often only while it is online,
  # so the value holds until the next reading
  state

  # Store the distance driven per day: the last reading before the end of
  # the day minus the last reading before its start. The reading holds, so
  # a day without a reading has no distance. SUM(daily_diff) equals the
  # total distance between the first and last known odometer reading in
  # any queried range.
  aggregations stored: %i[sum], meta: %i[sum], top10: true, meter: true

  # Distance is the SUM of the daily distances across the period.
  trend

  requires_permission :car
end
