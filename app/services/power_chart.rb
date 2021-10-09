class PowerChart < Flux::Reader
  def now
    chart_single start: '-60m', window: '5s', fill: true
  end

  def day(start, fill: false, interpolate: false)
    chart_single start: start.beginning_of_day,
                 stop: start.end_of_day,
                 window: '5m',
                 fill: fill,
                 interpolate: interpolate
  end

  def week(start)
    chart_sum start: start.beginning_of_week.beginning_of_day,
              stop: start.end_of_week.end_of_day,
              window: '1d'
  end

  def month(start)
    chart_sum start: start.beginning_of_month.beginning_of_day,
              stop: start.end_of_month.end_of_day,
              window: '1d'
  end

  def year(start)
    chart_sum start: start.beginning_of_year.beginning_of_day,
              stop: start.end_of_year.end_of_day,
              window: '1mo'
  end

  def all(start)
    chart_sum start: start.beginning_of_day, window: '1y'
  end

  private

  def chart_single(start:, window:, stop: nil, fill: false, interpolate: false)
    q = []

    q << 'import "interpolate"' if interpolate
    q << from_bucket
    q << "|> #{range(start: start, stop: stop)}"
    q << "|> #{measurements_filter}"
    q << "|> #{fields_filter}"

    if interpolate
      q << '|> map(fn:(r) => ({ r with _value: float(v: r._value) }))'
      q << "|> interpolate.linear(every: #{window})"
    end

    q << "|> aggregateWindow(every: #{window}, fn: mean)"
    q << '|> keep(columns: ["_time","_field","_value"])'
    q << '|> fill(usePrevious: true)' if fill

    raw = query(q.join)
    to_array(raw)
  end

  def chart_sum(start:, window:, stop: nil)
    raw = query <<-QUERY
      #{from_bucket}
      |> #{range(start: start, stop: stop)}
      |> #{measurements_filter}
      |> #{fields_filter}
      |> aggregateWindow(every: 1h, fn: mean)
      |> aggregateWindow(every: #{window}, fn: sum)
      |> keep(columns: ["_time","_field","_value"])
    QUERY

    to_array(raw)
  end

  def value_to_array(raw)
    result = []
    raw&.records&.each_with_index do |record, index|
      # InfluxDB returns data one-off
      next_record = raw.records[index + 1]
      next unless next_record

      time = Time.zone.parse(record.values['_time'] || '')
      value =
        case record.values['_field']
        when /power/, 'watt'
          # Fields with "power" in the name are given in W, so change them to kW
          (next_record.values['_value'].to_f / 1_000).round(3)
        else
          next_record.values['_value'].to_f
        end

      result << [time, value]
    end

    result
  end

  def to_array(raw)
    result = {}
    raw.each_key do |k|
      key = raw[k].records.first.values['_field']
      result[key] = value_to_array(raw[k])
    end

    result
  end
end
