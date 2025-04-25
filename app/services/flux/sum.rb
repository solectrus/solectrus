class Flux::Sum < Flux::Reader
  def call(timeframe: nil, start: nil, stop: nil)
    return {} unless SensorConfig.x.exists_any?(*sensors)

    start ||=
      timeframe&.beginning ||
        raise(ArgumentError, 'start or timeframe required')
    stop ||= timeframe&.beginning_of_next

    sum(start:, stop:)
  end

  private

  def sum(start:, stop: nil)
    query(build_query(start:, stop:)).each_with_object(
      empty_hash,
    ) do |table, hash|
      record = table.records.first

      sensor =
        SensorConfig.x.find_by(
          record.values['_measurement'],
          record.values['_field'],
        )

      hash[sensor] = record.values['_value'].clamp(0, nil)

      hash[:time] ||= Time.zone.parse record.values['_stop']
    end
  end

  def build_query(start:, stop:)
    <<~QUERY
      #{from_bucket}
      |> #{range(start:, stop:)}
      |> #{filter}
      |> integral(unit: 1h)
    QUERY
  end
end
