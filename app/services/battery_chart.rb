class BatteryChart < Flux::Reader
  def initialize(measurements:)
    super(measurements:, fields: %i[bat_fuel_charge])
  end

  def call(timeframe)
    case timeframe.id
    when :now
      chart_single start: 1.hour.ago,
                   stop: 1.second.since,
                   window: '5s',
                   fill: true
    when :day
      chart_single start: timeframe.beginning,
                   stop: timeframe.ending,
                   window: '5m'
    when :week, :month
      chart_minmax start: timeframe.beginning,
                   stop: timeframe.ending,
                   window: '1d'
    when :year
      chart_minmax_average start: timeframe.beginning,
                           stop: timeframe.ending,
                           window: '1mo'
    when :all
      chart_minmax_average start: timeframe.beginning,
                           stop: timeframe.ending,
                           window: '1y'
    end
  end

  private

  def chart_single(start:, window:, stop: nil, fill: false)
    q = []

    q << from_bucket
    q << "|> #{range(start:, stop:)}"
    q << "|> #{measurements_filter}"
    q << "|> #{fields_filter}"
    q << "|> aggregateWindow(every: #{window}, fn: mean)"
    q << '|> fill(usePrevious: true)' if fill
    q << '|> keep(columns: ["_time","_field","_value"])'

    raw = query(q.join)
    formatted(raw)
  end

  def chart_minmax(start:, window:, stop: nil)
    raw = query <<-QUERY
      #{from_bucket}
      |> #{range(start:, stop:)}
      |> #{measurements_filter}
      |> #{fields_filter}
      |> aggregateWindow(every: 5m, fn: mean)
      |> aggregateWindow(every: #{window}, fn: min)
      |> keep(columns: ["_time","_field","_value"])
      |> yield(name: "min")

      #{from_bucket}
      |> #{range(start:, stop:)}
      |> #{measurements_filter}
      |> #{fields_filter}
      |> aggregateWindow(every: 5m, fn: mean)
      |> aggregateWindow(every: #{window}, fn: max)
      |> keep(columns: ["_time","_field","_value"])
      |> yield(name: "max")
    QUERY

    formatted(raw)
  end

  def chart_minmax_average(start:, window:, stop: nil)
    raw = query <<-QUERY
      #{from_bucket}
      |> #{range(start:, stop:)}
      |> #{measurements_filter}
      |> #{fields_filter}
      |> aggregateWindow(every: 5m, fn: mean)
      |> aggregateWindow(every: 1d, fn: min)
      |> aggregateWindow(every: #{window}, fn: mean)
      |> keep(columns: ["_time","_field","_value"])
      |> yield(name: "min")

      #{from_bucket}
      |> #{range(start:, stop:)}
      |> #{measurements_filter}
      |> #{fields_filter}
      |> aggregateWindow(every: 5m, fn: mean)
      |> aggregateWindow(every: 1d, fn: max)
      |> aggregateWindow(every: #{window}, fn: mean)
      |> keep(columns: ["_time","_field","_value"])
      |> yield(name: "max")
    QUERY

    formatted(raw)
  end

  def formatted(raw)
    result = {}

    raw.each do |table|
      key = table.records.first.values['_field']
      array = table_to_array(table)

      result[key] = if result[key]
        # Merge the two tables
        merged_array = result[key].zip(array)
        merged_array.map! { |a, b| [a[0], [a[1], b[1]].sort] }
      else
        array
      end
    end

    result
  end

  def table_to_array(table)
    result = []

    table.records&.each_with_index do |record, index|
      # InfluxDB returns data one-off
      next_record = table.records[index + 1]
      next unless next_record

      time = Time.zone.parse(record.values['_time'] || '')
      value = next_record.values['_value'].to_f.round

      result << [time, value]
    end

    result
  end

  def default_cache_options
    { expires_in: 1.day }
  end
end
