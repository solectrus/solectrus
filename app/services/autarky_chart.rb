class AutarkyChart < Flux::Reader
  def initialize(measurements:)
    super(
      measurements:,
      fields: %i[house_power wallbox_charge_power grid_power_plus],
    )
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

  def chart_single(start:, window:, stop: nil, fill: false)
    q = []

    q << from_bucket
    q << "|> #{range(start:, stop:)}"
    q << "|> #{measurements_filter}"
    q << "|> #{fields_filter}"
    q << "|> aggregateWindow(every: #{window}, fn: mean)"
    q << '|> fill(usePrevious: true)' if fill
    q << '|> pivot(rowKey:["_time"], columnKey: ["_field"], valueColumn: "_value")'
    q << '|> map(fn: (r) => ({ r with autarky: 100.0 * (1.0 - (r.grid_power_plus / (r.house_power + (if r.wallbox_charge_power > 0 then r.wallbox_charge_power else 0.0)))) }))'
    q << '|> keep(columns: ["_time", "autarky"])'

    raw = query(q.join)
    to_array(raw)
  end

  def chart_sum(start:, window:, stop: nil)
    raw = query <<-QUERY
      import "timezone"

      #{from_bucket}
      |> #{range(start: start - 1.hour, stop:)}
      |> #{measurements_filter}
      |> #{fields_filter}
      |> aggregateWindow(every: 1h, fn: mean)
      |> aggregateWindow(every: #{window}, fn: sum, location: #{location})
      |> pivot(rowKey:["_time"], columnKey: ["_field"], valueColumn: "_value")
      |> map(fn: (r) => ({ r with autarky: 100.0 * (1.0 - (r.grid_power_plus / (r.house_power + (if r.wallbox_charge_power > 0 then r.wallbox_charge_power else 0.0)))) }))
      |> keep(columns: ["_time", "autarky"])
    QUERY

    to_array(raw)
  end

  def to_array(raw)
    value_to_array(raw[0])
  end

  def value_to_array(raw)
    result = []

    raw&.records&.each_with_index do |record, index|
      # InfluxDB returns data one-off
      next_record = raw.records[index + 1]
      next unless next_record

      time = Time.zone.parse(record.values['_time'])
      value = next_record.values['autarky']

      result << [time, value]
    end

    result
  end
end
