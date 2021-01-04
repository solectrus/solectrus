class FluxSum < FluxBase
  def now
    last('-1h')
  end

  def day
    range(Time.current.beginning_of_day.to_i)
  end

  def week
    range(Time.current.beginning_of_week.to_i)
  end

  def month
    range(Time.current.beginning_of_month.to_i)
  end

  def year
    range(Time.current.beginning_of_year.to_i)
  end

  def all
    range('0')
  end

  private

  def last(timeframe)
    result = query <<-QUERY
      #{from_bucket}
      |> #{range_since(timeframe)}
      |> #{measurement_filter}
      |> #{fields_filter}
      |> last()
    QUERY

    result.values.each_with_object(empty_hash) do |table, hash|
      record = table.records.first

      hash[record.values['_field'].to_sym] = record.values['_value']
      hash[:time] ||= Time.zone.parse record.values['_time']
    end
  end

  def range(timeframe)
    result = query <<-QUERY
      #{from_bucket}
      |> #{range_since(timeframe)}
      |> #{measurement_filter}
      |> #{fields_filter}
      |> aggregateWindow(every: 1h, fn: mean)
      |> sum()
    QUERY

    result.values.each_with_object(empty_hash) do |table, hash|
      record = table.records.first

      hash[record.values['_field'].to_sym] = record.values['_value']
      hash[:time] ||= Time.zone.parse record.values['_stop']
    end
  end

  def empty_hash
    result = {}
    @fields.each do |field|
      result[field] = nil
    end
    result[:time] = nil
    result
  end
end
