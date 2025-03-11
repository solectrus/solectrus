class Flux::Last < Flux::Reader
  def call
    return {} unless SensorConfig.x.exists_any?(*sensors)

    super(Timeframe.now)

    last(1.day.ago)
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
end
