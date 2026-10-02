# The distance of the selected cars, each car in a column of its own
class Sensor::Chart::CarMileage < Sensor::Chart::Base
  include Sensor::Chart::Concerns::SelectedCars

  def chart_sensor_names
    @chart_sensor_names ||= cars.map { Sensor::Cars.sensor_name(:car_mileage, it.id) }.select { Sensor::Config.exists?(it) }
  end

  # The label of each column names its car
  def label
    I18n.t('sensors.car_mileage')
  end

  # Always render as bar chart. The chart represents distance driven per
  # period (not a continuous signal), which is best shown as discrete bars.
  def type
    'bar'
  end

  private

  # The columns of the cars stack
  def build_dataset(sensor_name, chart_data)
    super.merge(label: Car.display_name_of(Sensor::Registry[sensor_name].car_number), stack: 'Car-Mileage')
  end

  # For Influx-based timeframes (hourly and single day), derive the distance
  # driven by computing consecutive differences between odometer samples and
  # bucketing them into full-hour sums. For day+/week/month/year we fall
  # through to the standard SQL-summary path.
  def build_data
    use_sql_for_timeframe? ? super : build_hourly_diff_data
  end

  def build_hourly_diff_data
    diffs = chart_sensor_names.index_with { hourly_diffs_from_raw_series(it) }
    hours = diffs.values.flat_map(&:keys).uniq.sort
    return if hours.empty?

    {
      labels: hours.map { it.to_i * 1000 },
      datasets:
        diffs.map do |sensor_name, buckets|
          build_dataset(sensor_name, data: hours.map { buckets.fetch(it, nil) })
        end,
    }
  end

  # { hour => km } of the odometer of one car
  def hourly_diffs_from_raw_series(sensor_name)
    points = sorted_raw_points(sensor_name)
    return {} if points.length < 2

    buckets = Hash.new(0.0)
    points.each_cons(2) { |a, b| accumulate_diff(buckets, a, b) }
    buckets
  end

  def sorted_raw_points(sensor_name)
    return [] unless series.respond_to?(sensor_name)

    raw_points = series.public_send(sensor_name, :avg, :avg)
    return [] if raw_points.blank?

    raw_points.compact.sort_by(&:first)
  end

  def accumulate_diff(buckets, (_prev_time, prev_val), (curr_time, curr_val))
    diff = (curr_val - prev_val).clamp(0..)
    return if diff.zero?

    hour_key = curr_time.to_time.beginning_of_hour
    buckets[hour_key] += diff
  end

  # car_mileage is sparse (see #sparse?), but the hourly diffs must not
  # reach before the window: a lookback sample would add bars for hours
  # outside the timeframe.
  def series_lookback
    0
  end
end
