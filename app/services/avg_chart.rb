class AvgChart < ChartBase
  def initialize(sensor:)
    super(sensors: [sensor])
    @sensor = sensor
  end

  attr_reader :average, :sensor

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
    when :week, :month, :year, :all
      chart_avg(timeframe:)
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
    q << '|> keep(columns: ["_time","_field","_measurement","_value"])'

    raw = query(q.join("\n"))
    formatted(raw)
  end

  def chart_avg(timeframe:)
    result =
      Summary
        .where(date: timeframe.beginning..timeframe.ending)
        .group_by_period(grouping_period(timeframe), :date)
        .calculate_all(:"avg_#{sensor}_avg")

    {
      sensor =>
        dates(timeframe).map { |date| [date.to_time, result[date].presence] },
    }
  end

  def remember_start(start)
    @start = start
  end

  def formatted(raw)
    result = {}

    raw.each do |table|
      field = table.records.first.values['_field']
      measurement = table.records.first.values['_measurement']
      sensor = SensorConfig.x.find_by(measurement, field)

      result[sensor] = table_to_array(table)
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
      value = record.values['_value']

      result << [time, value]
    end

    result
  end
end
