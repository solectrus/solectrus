class PowerSum < Flux::Reader
  def call(timeframe)
    return {} unless SensorConfig.x.exists_any?(*sensors)

    super

    timeframe.now? ? last(1.day.ago) : sum(timeframe:)
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

  def sum(timeframe:)
    price_sections(
      start: timeframe.beginning,
      stop: timeframe.ending,
    ).map do |section|
      sum_query(
        start: section[:starts_at].beginning_of_day,
        stop: section[:ends_at].end_of_day,
      ).tap do |query|
        query[:feed_in_tariff] = section[:feed_in]
        query[:electricity_price] = section[:electricity]
      end
    end
  end

  def price_sections(start:, stop:)
    DateInterval.new(
      starts_at: start.to_date,
      ends_at: stop&.to_date,
    ).price_sections
  end

  def sum_query(start:, stop: nil)
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
    if stop&.past? && (stop - start) > 31.days
      # Long period of time that is completely in the past:
      # Use fast query (with aggregateWindow(1h/mean))
      <<~QUERY
        #{from_bucket}
        |> #{range(start:, stop:)}
        |> #{filter}
        |> aggregateWindow(every: 1h, fn: mean, timeSrc: "_start")
        |> sum()
      QUERY
    else
      # Short period of time OR NOT completely in the past:
      # Use precise query (with "integral")
      <<~QUERY
        #{from_bucket}
        |> #{range(start:, stop:)}
        |> #{filter}
        |> integral(unit: 1h)
      QUERY
    end
  end

  def empty_hash
    sensors.index_with(nil).merge(time: nil)
  end
end
