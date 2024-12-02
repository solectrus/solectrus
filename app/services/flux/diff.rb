class Flux::Diff < Flux::Reader
  def call(timeframe: nil, start: nil, stop: nil)
    return {} unless SensorConfig.x.exists_any?(*sensors)

    start ||=
      timeframe&.beginning ||
        raise(ArgumentError, 'start or timeframe required')
    stop ||= timeframe&.ending

    run_query(start:, stop:)
  end

  private

  def run_query(start:, stop: nil)
    # puts query(build_query(start:, stop:)).first.records.first.values

    query(build_query(start:, stop:)).each_with_object({}) do |table, hash|
      record = table.records.first

      sensor =
        SensorConfig.x.find_by(
          record.values['_measurement'],
          record.values['_field'],
        )

      hash[:"diff_#{sensor}"] = record.values['_value']
    end
  end

  def build_query(start:, stop:)
    start_minus_gap = start - 1.week
    stop_plus_gap = stop + 1.week

    timestamp = start.strftime('%Y-%m-%dT%H:%M:%SZ')

    <<~QUERY
      import "interpolate"

      #{from_bucket}
      |> #{range(start: start_minus_gap, stop: stop_plus_gap)}
      |> #{filter}
      |> aggregateWindow(every: 1d, fn: last, createEmpty: false)
      |> interpolate.linear(every: 1d)
      |> difference(nonNegative: true)
      |> timeShift(duration: -1d)
      |> filter(fn: (r) => r._time == #{timestamp})
    QUERY
  end
end
