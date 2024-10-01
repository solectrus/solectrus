class PowerSum < Flux::Reader
  def call(timeframe)
    return {} unless SensorConfig.x.exists_any?(*sensors)

    super

    if timeframe.now?
      last(1.day.ago)
    else
      sum(start: timeframe.beginning, stop: timeframe.ending_with_last_second)
    end
  end

  private

  def last(start)
    result = query <<~QUERY
      #{from_bucket}
      |> #{range(start:)}
      |> #{filter}
      |> last()
    QUERY

    result.each_with_object(empty_hash) do |table, hash|
      record = table.records.first

      sensor =
        SensorConfig.x.find_by(
          record.values['_measurement'],
          record.values['_field'],
        )

      hash[sensor] = record.values['_value']

      # Get the latest time from all measurements
      # This is useful when the measurements are not in sync
      # The time is used to determine the "live" status of the system
      time = Time.zone.parse record.values['_time']
      hash[:time] = time if hash[:time].nil? || time > hash[:time]
    end
  end

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

      hash[sensor] = record.values['_value']

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

  def empty_hash
    sensors.index_with(nil).merge(time: nil)
  end
end
