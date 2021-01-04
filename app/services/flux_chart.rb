class FluxChart < FluxBase
  def now
    chart_single('-1h', '1m')
  end

  def day
    chart_single(Time.current.beginning_of_day.to_i, '5m')
  end

  def week
    chart_sum(Time.current.beginning_of_week.to_i, '1d')
  end

  def month
    chart_sum(Time.current.beginning_of_month.to_i, '1d')
  end

  def year
    chart_sum(Time.current.beginning_of_year.to_i, '1mo')
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
    raw.values[0].records.drop(1).map do |record|
      [
        Time.zone.parse(record.values['_time'] || ''),
        (record.values['_value'].to_f / 1_000).round(3)
      ]
    end
  end
end
