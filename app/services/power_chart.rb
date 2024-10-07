class PowerChart < Flux::Reader
  def call(timeframe, fill: false, interpolate: false)
    return {} unless SensorConfig.x.exists_any?(*sensors)

    super(timeframe)

    case timeframe.id
    when :now
      chart_single start: 1.hour.ago + 1.second,
                   stop: 1.second.since,
                   window: WINDOW[timeframe.id],
                   fill: true
    when :day
      chart_single start: timeframe.beginning,
                   stop: timeframe.ending,
                   window: WINDOW[timeframe.id],
                   fill:,
                   interpolate:
    when :week, :month, :year
      chart_sum start: timeframe.beginning,
                stop: timeframe.ending,
                window: WINDOW[timeframe.id]
    when :all
      chart_sum start: timeframe.beginning, window: WINDOW[timeframe.id]
    end
  end

  private

  def chart_single(start:, window:, stop: nil, fill: false, interpolate: false)
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
    end

    q << "|> aggregateWindow(every: #{window}, fn: mean)"
    q << '|> keep(columns: ["_time","_field","_measurement","_value"])'
    q << '|> fill(usePrevious: true)' if fill

    raw = query(q.join("\n"))
    to_array(raw, start:)
  end

  def chart_sum(start:, window:, stop: nil)
    raw = query <<~QUERY
      import "timezone"

      #{from_bucket}
      |> #{range(start: start - 1.second, stop:)}
      |> #{filter}
      |> aggregateWindow(every: 1h, fn: mean, timeSrc: "_start")
      |> aggregateWindow(every: #{window}, fn: sum, location: #{location})
      |> keep(columns: ["_time","_field","_measurement","_value"])
    QUERY

    to_array(raw, start:)
  end

  def value_to_array(raw, start:)
    result = []
    raw
      &.records
      &.each_cons(2) do |record, next_record|
        # InfluxDB returns data one-off
        value = next_record.values['_value']

        # Values are given in W, so change them to kW
        value &&= (value / 1_000).round(3)

        time = Time.zone.parse(record.values['_time'])

        # Take only values that are after the desired start
        # (needed because the start was extended by one hour)
        result << [time, value] if time >= start
      end
    result
  end

  def to_array(raw, start:)
    raw.each_with_object({}) do |r, result|
      first_record = r.records.first
      field = first_record.values['_field']
      measurement = first_record.values['_measurement']
      sensor = SensorConfig.x.find_by(measurement, field)

      result[sensor] = value_to_array(r, start:)
    end
  end
end
