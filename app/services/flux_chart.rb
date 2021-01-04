class FluxChart < FluxBase
  def now
    chart_single('-1h', '1m')
  end

  def day
    chart_sum('-24h', '1h')
  end

  def week
    chart_sum('-7d', '1d')
  end

  def month
    chart_sum('-30d', '1d')
  end

  def year
    chart_sum('-365d', '1mo')
  end

  def all
    chart_sum('0', '1y')
  end

  private

  def chart_single(timeframe, window)
    raw = query <<-QUERY
      #{from_bucket}
      |> #{range_since(timeframe)}
      |> #{measurement_filter}
      |> #{fields_filter}
      |> aggregateWindow(every: #{window}, fn: mean)
    QUERY

    to_array(raw)
  end

  def chart_sum(timeframe, window)
    raw = query <<-QUERY
      #{from_bucket}
      |> #{range_since(timeframe)}
      |> #{measurement_filter}
      |> #{fields_filter}
      |> aggregateWindow(every: 1h, fn: mean)
      |> aggregateWindow(every: #{window}, fn: sum)
    QUERY

    to_array(raw)
  end

  def to_array(raw)
    # TODO: Get all fields, not only the first one
    raw.values[0].records.map do |record|
      [
        Time.zone.parse(record.values['_time'] || ''),
        (record.values['_value'].to_f / 1_000).round(3)
      ]
    end
  end
end
