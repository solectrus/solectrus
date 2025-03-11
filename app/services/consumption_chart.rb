class ConsumptionChart < ChartBase
  def initialize
    super(sensors: %i[inverter_power grid_export_power])
  end

  def call(timeframe)
    return {} unless SensorConfig.x.exists_all?(*sensors)

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
    when :days, :week, :month, :months, :year, :all
      query_sql(timeframe:)
    end
  end

  private

  def inverter_power_field
    SensorConfig.x.field(:inverter_power)
  end

  def grid_export_power_field
    SensorConfig.x.field(:grid_export_power)
  end

  def chart_single(start:, window:, stop: nil)
    q = []

    q << from_bucket

    # To ensure that we capture data even when measurements are sparse (e.g. every 15 minutes),
    # we extend the time period backwards by one hour. From the data received,
    # everything outside the desired range is then filtered out.
    q << "|> #{range(start: start - 1.hour, stop:)}"

    q << "|> #{filter}"
    q << '|> aggregateWindow(every: 5s, fn: last)'
    q << '|> fill(usePrevious: true)'
    q << "|> aggregateWindow(every: #{window}, fn: mean)"
    q << '|> pivot(rowKey:["_time"], columnKey: ["_field"], valueColumn: "_value")'
    q << "|> map(fn: (r) => (
              { r with consumption:
                  if r.#{grid_export_power_field} > r.#{inverter_power_field} then
                    0.0
                  else
                    (100.0 * (r.#{inverter_power_field} - r.#{grid_export_power_field}) / r.#{inverter_power_field})
              }
             ))"
    q << '|> keep(columns: ["_time", "consumption"])'

    raw = query(q.join)
    to_array(raw, start:)
  end

  def query_sql(timeframe:)
    result =
      SummaryValue
        .where(
          date: timeframe.beginning..timeframe.ending,
          field: sensors,
          aggregation: 'sum',
        )
        .group_by_period(grouping_period(timeframe), :date)
        .group(:field)
        .sum(:value)

    dates(timeframe).map do |date|
      inverter_power = result[[date, 'inverter_power']]
      grid_export_power = result[[date, 'grid_export_power']]

      consumption =
        if inverter_power
          [inverter_power - (grid_export_power || 0), 0].max.fdiv(
            inverter_power,
          ) * 100
        end

      [date.to_time, consumption]
    end
  end

  def to_array(raw, start:)
    value_to_array(raw.first, start:)
  end

  def value_to_array(raw, start:)
    return [] unless raw&.records

    raw
      .records
      .each_cons(2) # InfluxDB returns data one-off
      .filter_map do |record, next_record|
        time = Time.zone.parse(record.values['_time'])

        # Take only data that ist after the desired start
        # (needed because the start was extended by one hour)
        next if time < start

        value =
          (next_record.values['consumption']&.clamp(0, 100) unless time.future?)

        [time, value]
      end
  end
end
