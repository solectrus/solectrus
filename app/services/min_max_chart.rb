class MinMaxChart < Flux::Reader
  def initialize(sensors:, average:)
    super(sensors:)
    @average = average
  end

  attr_reader :average

  def call(timeframe)
    return {} unless SensorConfig.x.exists_any?(*sensors)

    super

    case timeframe.id
    when :now
      chart_single start: 1.hour.ago + 1.second,
                   stop: 1.second.since,
                   window: WINDOW[timeframe.id]
    when :day
      chart_single start: timeframe.beginning,
                   stop: timeframe.ending,
                   window: WINDOW[timeframe.id]
    when :week, :month
      chart_minmax start: timeframe.beginning,
                   stop: timeframe.ending,
                   window: WINDOW[timeframe.id]
    when :year, :all
      chart_minmax_global start: timeframe.beginning,
                          stop: timeframe.ending,
                          window: WINDOW[timeframe.id]
    end
  end

  private

  def chart_single(start:, window:, stop: nil)
    remember_start(start)

    q = []

    q << from_bucket
    q << "|> #{range(start:, stop:)}"
    q << "|> #{filter}"
    q << "|> aggregateWindow(every: #{window}, fn: mean)"
    q << '|> fill(usePrevious: true)'
    q << '|> keep(columns: ["_time","_field","_measurement","_value"])'

    raw = query(q.join("\n"))
    formatted(raw)
  end

  def chart_minmax(start:, window:, stop: nil)
    remember_start(start)

    raw = query <<-QUERY
      import "timezone"

      #{from_bucket}
      |> #{range(start: start - 1.second, stop:)}
      |> #{filter}
      |> aggregateWindow(every: 5m, fn: mean)
      |> aggregateWindow(every: #{window}, fn: min, location: #{location})
      |> keep(columns: ["_time","_field","_measurement","_value"])
      |> yield(name: "min")

      #{from_bucket}
      |> #{range(start: start - 1.second, stop:)}
      |> #{filter}
      |> aggregateWindow(every: 5m, fn: mean)
      |> aggregateWindow(every: #{window}, fn: max, location: #{location})
      |> keep(columns: ["_time","_field","_measurement","_value"])
      |> yield(name: "max")
    QUERY

    formatted(raw)
  end

  def chart_minmax_global(start:, window:, stop: nil)
    remember_start(start)

    raw = query <<-QUERY
      import "timezone"

      #{from_bucket}
      |> #{range(start: start - 1.second, stop:)}
      |> #{filter}
      |> aggregateWindow(every: 5m, fn: mean)
      |> aggregateWindow(every: 1d, fn: min)
      |> aggregateWindow(every: #{window}, fn: #{average ? 'mean' : 'min'}, location: #{location})
      |> keep(columns: ["_time","_field","_measurement","_value"])
      |> yield(name: "min")

      #{from_bucket}
      |> #{range(start: start - 1.second, stop:)}
      |> #{filter}
      |> aggregateWindow(every: 5m, fn: mean)
      |> aggregateWindow(every: 1d, fn: max)
      |> aggregateWindow(every: #{window}, fn: #{average ? 'mean' : 'max'}, location: #{location})
      |> keep(columns: ["_time","_field","_measurement","_value"])
      |> yield(name: "max")
    QUERY

    formatted(raw)
  end

  def remember_start(start)
    @start = start
  end

  # Get the last value BEFORE the start time
  def previous_value
    return unless @start

    @previous_value ||=
      begin
        raw = query <<-QUERY
          #{from_bucket}
          |> #{range(start: @start - 1.day, stop: @start)}
          |> #{filter}
          |> last()
        QUERY

        raw.first&.records&.first&.value
      end
  end

  def formatted(raw)
    result = {}

    raw.each do |table|
      field = table.records.first.values['_field']
      measurement = table.records.first.values['_measurement']
      sensor = SensorConfig.x.find_by(measurement, field)

      array = table_to_array(table)

      result[sensor] = if result[sensor]
        # Merge the two tables
        merged_array = result[sensor].zip(array)
        # Return array with [time, [min, max]] or [time, nil]
        merged_array.map! do |a, b|
          time = a.first
          minmax = [a[1], b[1]]
          minmax.sort!
          minmax.compact!

          [time, minmax.presence]
        end
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

      time = Time.zone.parse(record.values['_time'])
      value = value_from_record(time:, record: next_record)

      result << [time, value]
    end

    result
  end

  def value_from_record(time:, record:)
    if time.future?
      # Becaue of fill(previous: true) we need to remove future values
      nil
    else
      original = record.values['_value']

      # In case of missing data at the beginning, fill in previous value
      if original.nil? && time < record.time
        previous_value
      else
        original
      end
    end
  end

  def default_cache_options
    return unless timeframe

    # Cache larger timeframes, but just for a short time
    return { expires_in: 10.minutes } if timeframe.month? || timeframe.week?
    return { expires_in: 1.hour } if timeframe.year?
    return { expires_in: 1.day } if timeframe.all?

    nil
  end
end
