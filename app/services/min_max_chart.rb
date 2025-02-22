class MinMaxChart < ChartBase
  def initialize(sensor:, average:)
    super(sensors: [sensor])
    @average = average
    @sensor = sensor
  end

  attr_reader :average, :sensor

  def call(timeframe)
    return {} unless SensorConfig.x.exists_any?(*sensors)

    super

    case timeframe.id
    when :now
      query_influx start: 1.hour.ago + 1.second,
                   stop: 1.second.since,
                   window: WINDOW[timeframe.id]
    when :day
      query_influx start: timeframe.beginning,
                   stop: timeframe.ending,
                   window: WINDOW[timeframe.id]
    when :week, :month, :year, :all
      query_sql(timeframe:)
    end
  end

  private

  def query_influx(start:, window:, stop: nil)
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

  def query_sql(timeframe:)
    result =
      SummaryValue
        .where(date: timeframe.beginning..timeframe.ending)
        .where(field: sensors, aggregation: %w[min max].uniq)
        .group_by_period(grouping_period(timeframe), :date)
        .group(:field, :aggregation)
        .average(:value)

    {
      sensor =>
        dates(timeframe).map do |date|
          min = result[[date, sensor.to_s, 'min']]
          max = result[[date, sensor.to_s, 'max']]

          [date.to_time, [min, max].compact.presence]
        end,
    }
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

        raw.first.records&.first&.value if raw.first.present?
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

      # Override the value if it's in the future (may be present because of filling)
      value = nil if time.future?

      result << [time, value]
    end

    result
  end

  def value_from_record(time:, record:)
    if time.future?
      # Because of fill(previous: true) we need to remove future values
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
end
