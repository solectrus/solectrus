class Sensor::Definitions::CarMaxRange < Sensor::Definitions::Base
  include Sensor::Definitions::CarNumber

  value unit: :kilometer, range: (0..), category: :car

  # Derived from the range and the state of charge, so the same long gaps are
  # normal.
  max_age 2.hours

  color background: 'bg-sensor-car-range', text: 'text-white dark:text-slate-400'

  icon 'road'

  # A summary stores the daily average, so a SQL query reads its own field.
  # The formula over the averages of a period is not the average of its days.
  depends_on do |context: :unknown|
    next [name, range_name, soc_name] if context == :sql

    [range_name, soc_name]
  end

  # The block form hides the dependencies from Sensor::Config#exists?, which
  # then cannot prune an unconfigured number.
  def static_dependencies = dependencies

  # Extrapolate the current range to a theoretical 100% state of charge.
  calculate do |**values|
    stored = values[name]
    next stored if stored

    range = values[range_name]
    soc = values[soc_name]
    next unless range && soc&.positive?

    range * 100.0 / soc
  end

  # Store the daily average of the extrapolated max range so battery
  # degradation (and charging state trends) can be tracked historically.
  aggregations stored: %i[avg], meta: %i[avg], top10: true

  # Higher max range is better (less battery degradation).
  trend aggregation: :avg, more_is_better: true

  requires_permission :car

  private

  def range_name = Sensor::Cars.sensor_name(:car_range, car_number)

  def soc_name = Sensor::Cars.sensor_name(:car_battery_soc, car_number)
end
