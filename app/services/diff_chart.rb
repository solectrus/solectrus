class DiffChart < ChartBase
  def initialize(source_sensor:, target_sensor:)
    super(sensors: [source_sensor])

    @target_sensor = target_sensor
  end

  attr_reader :target_sensor

  def call(timeframe)
    return {} unless SensorConfig.x.exists_any?(*sensors)

    timeframe.short? ? chart_influx(timeframe:) : chart_summary(timeframe:)
  end

  private

  def chart_influx(timeframe:)
    start = timeframe.beginning
    stop = timeframe.ending

    q = []
    q << 'import "interpolate"'
    q << from_bucket

    # To ensure that we capture data even when measurements are sparse (e.g. every 15 minutes),
    # we extend the time period backwards by one hour. From the data received,
    # everything outside the desired range is then filtered out.
    q << "|> #{range(start: start - 1.hour, stop:)}"
    q << "|> #{filter}"
    q << '|> difference(nonNegative: true)'
    q << '|> aggregateWindow(every: 1h, fn: sum)'

    raw = query(q.join("\n"))
    to_array(raw, start:)
  end

  def chart_summary(timeframe:)
    result =
      Summary
        .where(date: timeframe.beginning..timeframe.ending)
        .group_by_period(grouping_period(timeframe), :date)
        .calculate_all(:"sum_#{target_sensor}")

    # Filter only sensors with at least one non-nil value in the result
    sensors_with_values =
      [target_sensor].select do |sensor|
        result.values.any? { |value| float_from_calculate_all(sensor, value) }
      end

    # Return a Hash with the sensors as keys and nested arrays with [date, value] as values
    # Example:
    #   { heatpump_power: [[date1, 123.1], [date2, 42.5], ... }
    sensors_with_values.index_with do |sensor|
      dates(timeframe).map do |date|
        value = float_from_calculate_all(sensor, result[date])

        [date.to_time, value]
      end
    end
  end

  # Gem "calculate_all" returns a Hash for multiple fields and a Float for a single field.
  # This method helps to get the float from the result.
  def float_from_calculate_all(sensor, value)
    value.is_a?(Hash) ? value[:"sum_#{sensor}_sum"] : value
  end

  def value_to_array(raw, start:)
    result = []
    raw
      &.records
      &.each_cons(2) do |record, next_record|
        # InfluxDB returns data one-off
        value = next_record.values['_value']

        time = Time.zone.parse(record.values['_time'])

        # Take only values that are after the desired start
        # (needed because the start was extended by one hour)
        result << [time, value] if time >= start
      end
    result
  end

  def to_array(raw, start:)
    raw.each_with_object({}) do |r, result|
      result[target_sensor] = value_to_array(r, start:)
    end
  end
end
