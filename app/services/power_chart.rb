class PowerChart < ChartBase
  def call(timeframe, interpolate: false)
    return {} unless SensorConfig.x.exists_any?(*sensors)

    super(timeframe)

    case timeframe.id
    when :now
      query_influx start: 1.hour.ago + 1.second,
                   stop: 1.second.since,
                   window: WINDOW[timeframe.id]
    when :day
      query_influx start: timeframe.beginning,
                   stop: timeframe.ending,
                   window: WINDOW[timeframe.id],
                   interpolate:
    when :days, :week, :month, :months, :year, :all
      query_sql(timeframe:)
    end
  end

  private

  def query_influx(start:, window:, stop: nil, interpolate: false)
    q = []

    q << 'import "interpolate"' if interpolate
    q << from_bucket

    # To ensure that we capture data even when measurements are sparse (e.g. every 15 minutes),
    # we extend the time period backwards by one hour. From the data received,
    # everything outside the desired range is then filtered out.
    q << "|> #{range(start: start - 1.hour, stop:)}"

    q << "|> #{filter}"

    if interpolate
      q << '|> map(fn:(r) => ({ r with _value: float(v: r._value) }))'
      q << "|> interpolate.linear(every: #{window})"
    else
      q << '|> aggregateWindow(every: 5s, fn: last)'
      q << '|> fill(usePrevious: true)'
    end

    q << "|> aggregateWindow(every: #{window}, fn: mean)"
    q << '|> keep(columns: ["_time","_field","_measurement","_value"])'

    raw = query(q.join("\n"))
    to_array(raw, start:, interpolate:)
  end

  def query_sql(timeframe:)
    result =
      SummaryValue
        .where(
          date: timeframe.beginning..timeframe.ending,
          field: sensors,
          aggregation: 'sum',
        )
        .group_by_period(grouping_period(timeframe), :date)
        .group(:field)
        .sum(:value)

    # Filter only sensors with at least one non-nil value in the result
    sensors_with_values =
      sensors.select do |sensor|
        result.any? do |(_date, key), value|
          key == sensor.to_s && value.present?
        end
      end

    # Return a Hash with the sensors as keys and nested arrays with [date, value] as values
    # Example:
    #   { heatpump_power: [[date1, 123.1], [date2, 42.5], ... }
    sensors_with_values.index_with do |sensor|
      dates(timeframe).map do |date|
        value = result[[date, sensor.to_s]]

        [date.to_time, value]
      end
    end
  end

  def value_to_array(raw, start:, interpolate:)
    raw
      .records
      .each_cons(2) # InfluxDB returns data one-off
      .filter_map do |record, next_record|
        time = Time.zone.parse(record.values['_time'])

        # Take only data that ist after the desired start
        # (needed because the start was extended by one hour)
        next if time < start

        # Future values should not be shown when using fill(usePrevious: true)
        use_value = interpolate || !time.future?
        value = next_record.values['_value']&.round if use_value

        [time, value]
      end
  end

  def to_array(raw, start:, interpolate:)
    raw.each_with_object({}) do |r, result|
      first_record = r.records.first
      field = first_record.values['_field']
      measurement = first_record.values['_measurement']
      sensor = SensorConfig.x.find_by(measurement, field)

      result[sensor] = value_to_array(r, start:, interpolate:)
    end
  end
end
