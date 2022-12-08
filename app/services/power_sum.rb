class PowerSum < Flux::Reader
  def call(timeframe)
    case timeframe.id
    when :now
      last('-5m')
    else
      sum start: timeframe.beginning,
          stop: timeframe.ending,
          cache_options:
            timeframe.year? || timeframe.all? ? { expires_in: 1.day } : nil
    end
  end

  private

  def last(start)
    result = query <<-QUERY
      #{from_bucket}
      |> #{range(start:)}
      |> #{measurements_filter}
      |> #{fields_filter}
      |> last()
    QUERY

    result.each_with_object(empty_hash) do |table, hash|
      record = table.records.first

      hash[record.values['_field'].to_sym] = record.values['_value']
      hash[:time] ||= Time.zone.parse record.values['_time']
    end
  end

  def sum(start:, stop: nil, cache_options: nil)
    price_sections(start:, stop:).map do |section|
      sum_query(
        start: section[:starts_at],
        stop: section[:ends_at],
        cache_options:,
      ).tap do |query|
        query[:feed_in_tariff] = section[:feed_in]
        query[:electricity_price] = section[:electricity]
      end
    end
  end

  def price_sections(start:, stop:)
    DateInterval.new(
      starts_at: start.to_time,
      ends_at: stop&.to_time,
    ).price_sections
  end

  def sum_query(start:, stop: nil, cache_options: nil)
    result = query(<<-QUERY, cache_options:)
      #{from_bucket}
      |> #{range(start:, stop:)}
      |> #{measurements_filter}
      |> #{fields_filter}
      |> integral(unit:1h)
    QUERY

    result.each_with_object(empty_hash) do |table, hash|
      record = table.records.first

      hash[record.values['_field'].to_sym] = record.values['_value']
      hash[:time] ||= Time.zone.parse record.values['_stop']
    end
  end

  def empty_hash
    result = {}
    fields.each { |field| result[field] = nil }
    result[:time] = nil
    result
  end
end
