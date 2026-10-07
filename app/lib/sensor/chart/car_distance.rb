# The distance of the selected cars, each car in a part of its own. A day
# draws the distance since midnight as a line, from the odometer in InfluxDB.
# A longer timeframe takes the distance from the daily summaries, so a column
# is a day at least.
class Sensor::Chart::CarDistance < Sensor::Chart::Base
  include Sensor::Chart::Concerns::SelectedCars

  def self.supports?(timeframe)
    timeframe.day? || !timeframe.short?
  end

  # Only a car with an odometer has a distance
  def supported?
    super && cars.any? { it.sensor?(:car_odometer) }
  end

  # A day reads InfluxDB directly, so it leaves out a car outside its period
  # of use. A longer timeframe reads the daily values, which hold no value
  # outside it (see Sensor::Summarizer).
  def chart_sensor_names
    @chart_sensor_names ||=
      cars
      .select { !timeframe.day? || it.active_on?(timeframe.date) }
      .select { it.sensor?(:car_odometer) }
      .map { it.sensor_name(:car_odometer) }
  end

  # The label of each part names its car
  def label
    I18n.t('sensors.car_distance')
  end

  private

  # A timeframe without a car in use has no distance
  def build_data
    super if chart_sensor_names.any?
  end

  # The parts of the cars stack. Several cars tint each part with the color of
  # its car.
  def build_dataset(sensor_name, chart_data)
    car_number = Sensor::Registry[sensor_name].car_number
    tint_color = cars.find { it.id == car_number }&.display_color if cars.many?

    super.merge(label: Car.display_name_of(car_number), stack: 'CarDistance', summed: true, tintColor: tint_color).compact
  end

  # A day shows the odometer minus its reading at midnight. The line runs from
  # 0 to the reading at the end of the day, both readings interpolated like
  # the daily summary (see DailyDiffs), so it ends at the distance of the day.
  #
  # Without a reading at a midnight, for example on the installation date,
  # the day has no distance, like its summary. The line then stays empty and
  # never shows the odometer itself.
  def transform_data(data, sensor_name)
    return super unless timeframe.day? && data.any?

    bounds = day_bounds[sensor_name]
    super(bounds&.all? ? distances(data, *bounds) : Array.new(data.size), sensor_name)
  end

  # The distance since midnight of each reading, from 0 to the distance of
  # the day. A reading outside is wrong, for example a 0 of an offline car
  # (see Sensor::MeterReadings), so the line skips it.
  def distances(data, start_value, end_value)
    total = end_value - start_value

    data.map { it && (it - start_value).then { |distance| distance if distance.between?(0, total) } }.tap do |result|
      result[0] ||= 0
      result[-1] ||= total
    end
  end

  # { sensor_name => [start_value, end_value] }
  def day_bounds
    return {} unless timeframe.day?

    @day_bounds ||=
      Sensor::Query::Helpers::Influx::DailyDiffs
        .new([timeframe.date], chart_sensor_names, cache: true)
        .bounds
        .fetch(timeframe.date, {})
  end

  # The line ramps between the readings over the whole day, like the daily
  # summary, instead of the steps of a state. It needs no start before
  # midnight.
  def holds_value? = false

  def gap_bridge_limit = 1.day.in_milliseconds
end
