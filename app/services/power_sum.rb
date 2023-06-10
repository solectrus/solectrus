class PowerSum < Flux::Reader
  def call(timeframe)
    @timeframe = timeframe

    if timeframe.id == :now
      last(5.minutes.ago)
    else
      sum(timeframe:)
    end
  end

  private

  def last(start)
    result = query <<-QUERY
      #{from_bucket}
      |> #{range(start:, stop: 1.second.since)}
      |> #{measurements_filter}
      |> #{fields_filter}
      |> last()
    QUERY

    result.each_with_object(empty_hash) do |table, hash|
      record = table.records.first

      hash[record.values['_field'].to_sym] = record.values['_value']

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

      hash[record.values['_field'].to_sym] = record.values['_value']
      hash[:time] ||= Time.zone.parse record.values['_stop']
    end
  end

  def build_query(start:, stop:)
    if stop && stop < Time.current
      # Range from the past, use more precise query
      <<-QUERY
        import "timezone"

        #{from_bucket}
        |> #{range(start: start - 1.hour, stop:)}
        |> #{measurements_filter}
        |> #{fields_filter}
        |> aggregateWindow(every: 1h, fn: mean)
        |> aggregateWindow(every: 1d, fn: sum, location: #{location})
        |> sum()
      QUERY
    else
      # Current range, use "integral" because aggregateWindow(1h/mean) is
      # not correct for incomplete measurements
      <<-QUERY
        #{from_bucket}
        |> #{range(start:, stop:)}
        |> #{measurements_filter}
        |> #{fields_filter}
        |> integral(unit: 1h)
      QUERY
    end
  end

  def empty_hash
    fields.index_with(nil).merge(time: nil)
  end

  def default_cache_options
    # Cache larger timeframes, but just for a short time
    return { expires_in: 1.day } if @timeframe&.all?
    return { expires_in: 1.hour } if @timeframe&.year?
  end
end
