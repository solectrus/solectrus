class AutarkyChart < Flux::Reader
  def initialize(measurements:)
    super(
      measurements:,
      fields: %i[house_power wallbox_charge_power grid_power_plus]
    )
  end

  def now
    chart_single start: '-60m', window: '5s', fill: true
  end

  def day(start, fill: false)
    chart_single start: start.beginning_of_day,
                 stop: start.end_of_day,
                 window: '5m',
                 fill:
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

  def chart_single(start:, window:, stop: nil, fill: false)
    q = []

    q << from_bucket
    q << "|> #{range(start:, stop:)}"
    q << "|> #{measurements_filter}"
    q << "|> #{fields_filter}"
    q << "|> aggregateWindow(every: #{window}, fn: mean)"
    q << '|> fill(usePrevious: true)' if fill
    q << '|> pivot(rowKey:["_time"], columnKey: ["_field"], valueColumn: "_value")'
    q << '|> map(fn: (r) => ({ r with autarky: 100.0 * (1.0 - (r.grid_power_plus / (r.house_power + r.wallbox_charge_power))) }))'
    q << '|> keep(columns: ["_time", "autarky"])'

    raw = query(q.join)
    to_array(raw)
  end

  def chart_sum(start:, window:, stop: nil)
    raw = query <<-QUERY
      #{from_bucket}
      |> #{range(start:, stop:)}
      |> #{measurements_filter}
      |> #{fields_filter}
      |> aggregateWindow(every: 1h, fn: mean)
      |> aggregateWindow(every: #{window}, fn: sum)
      |> pivot(rowKey:["_time"], columnKey: ["_field"], valueColumn: "_value")
      |> map(fn: (r) => ({ r with autarky: 100.0 * (1.0 - (r.grid_power_plus / (r.house_power + r.wallbox_charge_power))) }))
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

      time = Time.zone.parse(record.values['_time'] || '')
      value = next_record.values['autarky'].to_f

      result << [time, value]
    end

    result
  end
end
