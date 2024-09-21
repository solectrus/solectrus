class AutarkyChart < Flux::Reader
  def initialize
    super(sensors: %i[house_power wallbox_power grid_import_power])
  end

  def call(timeframe, fill: false)
    return {} unless SensorConfig.x.exists?(:autarky)

    super(timeframe)

    case timeframe.id
    when :now
      chart_single start: 60.minutes.ago,
                   stop: 1.second.since,
                   window: WINDOW[timeframe.id],
                   fill: true
    when :day
      chart_single start: timeframe.beginning,
                   stop: timeframe.ending,
                   window: WINDOW[timeframe.id],
                   fill:
    when :week, :month, :year, :all
      chart_sum start: timeframe.beginning,
                stop: timeframe.ending,
                window: WINDOW[timeframe.id]
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

  def chart_single(start:, window:, stop: nil, fill: false)
    q = []

    q << from_bucket

    # To ensure that we capture data even when measurements are sparse (e.g. every 15 minutes),
    # we extend the time period backwards by one hour. From the data received,
    # everything outside the desired range is then filtered out.
    q << "|> #{range(start: start - 1.hour, stop:)}"

    q << "|> #{filter}"
    q << "|> aggregateWindow(every: #{window}, fn: mean)"
    q << '|> fill(usePrevious: true)' if fill
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

  def chart_sum(start:, window:, stop: nil)
    q = []

    q << 'import "timezone"'
    q << from_bucket
    q << "|> #{range(start: start - 1.second, stop:)}"
    q << "|> #{filter}"
    q << '|> aggregateWindow(every: 1h, fn: mean, timeSrc: "_start")'
    q << "|> aggregateWindow(every: #{window}, fn: sum, location: #{location})"
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

  def to_array(raw, start:)
    value_to_array(raw.first, start:)
  end

  def value_to_array(raw, start:)
    result = []

    raw&.records&.each_with_index do |record, index|
      # InfluxDB returns data one-off
      next_record = raw.records[index + 1]
      next unless next_record

      time = Time.zone.parse(record.values['_time'])
      value = next_record.values['autarky']

      # Take only values that are after the desired start
      # (needed because the start was extended by one hour)
      result << [time, value] if time >= start
    end

    result
  end
end
