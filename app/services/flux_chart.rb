class FluxChart < FluxBase
  def now
    chart_single start: '-15m', window: '5s'
  end

  def day
    chart_single start: Time.current.beginning_of_day.iso8601, stop: Time.current.end_of_day.iso8601, window: '5m'
  end

  def week
    chart_sum start: Time.current.beginning_of_week.iso8601, stop: Time.current.end_of_week.iso8601, window: '1d'
  end

  def month
    chart_sum start: Time.current.beginning_of_month.iso8601, stop: Time.current.end_of_month.iso8601, window: '1d'
  end

  def year
    chart_sum start: Time.current.beginning_of_year.iso8601, stop: Time.current.end_of_year.iso8601, window: '1mo'
  end

  def all
    chart_sum start: '-10y', stop: Time.current.iso8601, window: '1y'
  end

  private

  def chart_single(start:, window:, stop: nil)
    raw = query <<-QUERY
      #{from_bucket}
      |> #{range(start: start, stop: stop)}
      |> #{measurement_filter}
      |> #{fields_filter}
      |> aggregateWindow(every: #{window}, fn: mean)
      #{stop.nil? && '|> fill(usePrevious: true)'}
    QUERY

    to_array(raw)
  end

  def chart_sum(start:, window:, stop: nil)
    raw = query <<-QUERY
      #{from_bucket}
      |> #{range(start: start, stop: stop)}
      |> #{measurement_filter}
      |> #{fields_filter}
      |> aggregateWindow(every: 1h, fn: mean)
      |> aggregateWindow(every: #{window}, fn: sum)
    QUERY

    to_array(raw)
  end

  def to_array(raw)
    # TODO: Get all fields, not only the first one
    result = []
    raw.values[0].records.each_with_index do |record, index|
      # InfluxDB returns data one-off
      next_record = raw.values[0].records[index + 1]
      next unless next_record

      time = Time.zone.parse(record.values['_time'] || '')
      value = (next_record.values['_value'].to_f / 1_000).round(3)

      result << [ time, value ]
    end
    result
  end
end
