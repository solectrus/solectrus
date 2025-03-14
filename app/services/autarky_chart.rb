class AutarkyChart < ChartBase
  def initialize
    super(sensors: %i[house_power wallbox_power grid_import_power])
  end

  def call(timeframe)
    return {} unless SensorConfig.x.exists?(:autarky)

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
    when :days, :week, :month, :months, :year, :years, :all
      query_sql(timeframe:)
    end
  end

  private

  def house_power_field
    SensorConfig.x.field(:house_power)
  end

  def wallbox_power_field
    SensorConfig.x.field(:wallbox_power)
  end

  def grid_import_power_field
    SensorConfig.x.field(:grid_import_power)
  end

  def query_influx(start:, window:, stop: nil)
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

    q << if wallbox_power_field
      '|> map(fn: (r) => ({ r with autarky: 100.0 * (1.0 - ' \
        "(r.#{grid_import_power_field} / (r.#{house_power_field} + (if r.#{wallbox_power_field} > 0 then r.#{wallbox_power_field} else 0.0)))) }))"
    else
      '|> map(fn: (r) => ({ r with autarky: 100.0 * (1.0 - ' \
        "(r.#{grid_import_power_field} / (r.#{house_power_field}))) }))"
    end

    q << '|> keep(columns: ["_time", "autarky"])'

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
      grid_import_power = result[[date, 'grid_import_power']]
      house_power = result[[date, 'house_power']]
      wallbox_power = result[[date, 'wallbox_power']]

      autarky =
        if grid_import_power
          (1 - grid_import_power.fdiv(house_power + (wallbox_power || 0))) * 100
        end

      [date.to_time, autarky&.clamp(0, 100)]
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
          (next_record.values['autarky']&.clamp(0, 100) unless time.future?)

        [time, value]
      end
  end
end
