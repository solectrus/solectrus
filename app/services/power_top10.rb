class PowerTop10 < Flux::Reader
  def days
    top start: first_day, stop: last_day, window: '1d'
  end

  def months
    top start: first_day, stop: last_day, window: '1mo'
  end

  def years
    top start: first_day, stop: last_day, window: '1y'
  end

  private

  def first_day
    Rails.configuration.x.installation_date.beginning_of_day
  end

  def last_day
    Time.current
  end

  def top(start:, stop:, window:, limit: 10)
    raw = query <<-QUERY
      #{from_bucket}
      |> #{range(start: start, stop: stop)}
      |> #{measurements_filter}
      |> #{fields_filter}
      |> aggregateWindow(every: 1h, fn: mean)
      |> aggregateWindow(every: #{window}, fn: sum)
      |> filter(fn: (r) => r._value > 0)
      |> sort(desc: true)
      |> limit(n: #{limit})
    QUERY

    return [] unless raw.values[0]

    raw.values[0].records.map do |record|
      time = Time.zone.parse(record.values['_time'] || '').utc - 1.second
      value = record.values['_value'].to_f

      [ time.to_date, value ]
    end
  end
end
