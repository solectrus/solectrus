class ConsumptionChart < Flux::Reader
  def initialize
    super(sensors: %i[inverter_power grid_power_export])
  end

  def call(timeframe, fill: false)
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

  def inverter_power_field
    Rails.application.config.x.influx.sensors.field(:inverter_power)
  end

  def grid_power_export_field
    Rails.application.config.x.influx.sensors.field(:grid_power_export)
  end

  def chart_single(start:, window:, stop: nil, fill: false)
    q = []

    q << from_bucket
    q << "|> #{range(start:, stop:)}"
    q << "|> #{filter}"
    q << "|> aggregateWindow(every: #{window}, fn: mean)"
    q << '|> fill(usePrevious: true)' if fill
    q << '|> pivot(rowKey:["_time"], columnKey: ["_field"], valueColumn: "_value")'
    q << "|> map(fn: (r) => (
              { r with consumption:
                  if r.#{grid_power_export_field} > r.#{inverter_power_field} then
                    0.0
                  else
                    (100.0 * (r.#{inverter_power_field} - r.#{grid_power_export_field}) / r.#{inverter_power_field})
              }
             ))"
    q << '|> keep(columns: ["_time", "consumption"])'

    raw = query(q.join)
    to_array(raw)
  end

  def chart_sum(start:, window:, stop: nil)
    raw = query <<~QUERY
      import "timezone"

      #{from_bucket}
      |> #{range(start: start - 1.hour, stop:)}
      |> #{filter}
      |> aggregateWindow(every: 1h, fn: mean)
      |> aggregateWindow(every: #{window}, fn: sum, location: #{location})
      |> pivot(rowKey:["_time"], columnKey: ["_field"], valueColumn: "_value")
      |> map(fn: (r) => ({ r with consumption: if r.#{grid_power_export_field} > r.#{inverter_power_field} then 0.0 else 100.0 * (r.#{inverter_power_field} - r.#{grid_power_export_field}) / r.#{inverter_power_field} }))
      |> keep(columns: ["_time", "consumption"])
    QUERY

    to_array(raw)
  end

  def to_array(raw)
    value_to_array(raw.first)
  end

  def value_to_array(raw)
    result = []

    raw&.records&.each_with_index do |record, index|
      # InfluxDB returns data one-off
      next_record = raw.records[index + 1]
      next unless next_record

      time = Time.zone.parse(record.values['_time'])
      value = next_record.values['consumption']

      result << [time, value]
    end

    result
  end
end
