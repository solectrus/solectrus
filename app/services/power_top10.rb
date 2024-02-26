class PowerTop10 < Flux::Reader
  def initialize(sensor:, desc:, calc:)
    @sensor = sensor
    @calc = ActiveSupport::StringInquirer.new(calc)
    @desc = desc

    super(sensors: [sensor])
  end

  attr_reader :sensor, :calc, :desc

  def days
    top start: start(:day), stop: stop(:day), window: '1d'
  end

  def weeks
    # In InfluxDB the weeks start on Thursday (!) by default, so we have to shift by 3 days to get the weeks starting on Monday
    # https://docs.influxdata.com/flux/v0.x/stdlib/universe/aggregatewindow/#downsample-by-calendar-week-starting-on-monday
    top start: start(:week), stop: stop(:week), window: '1w', offset: '-3d'
  end

  def months
    top start: start(:month), stop: stop(:month), window: '1mo'
  end

  def years
    top start: start(:year), stop: stop(:year), window: '1y'
  end

  private

  def start(period)
    raw = Rails.configuration.x.installation_date.beginning_of_day
    # In ascending order, the first period may not be included because it is (most likely) not complete
    adjustment = desc ? 0 : 1.public_send(period)

    (raw + adjustment).public_send(:"beginning_of_#{period}")
  end

  def stop(period)
    raw = Date.current.end_of_day
    # In ascending order, the current period may not be included because it is not yet complete
    adjustment = desc ? 0 : 1.public_send(period)

    (raw - adjustment).public_send(:"end_of_#{period}")
  end

  def top(start:, stop:, window:, limit: 10, offset: '0s')
    return [] if start > stop

    raw = query(build_query(start:, stop:, window:, limit:, offset:))
    return [] unless raw.first

    raw.first.records.map do |record|
      time = Time.zone.parse(record.values['_time']).utc - 1.second
      value = record.values['_value']

      { date: time.to_date, value: }
    end
  end

  def default_cache_options
    # Performing the peak query is slow, so we cache the results for longer
    { expires_in: calc.max? ? 2.hours : 10.minutes }
  end

  def first_aggregate_window
    if calc.sum?
      # Average per hour (to get kWh)
      'aggregateWindow(every: 1h, fn: mean)'
    elsif calc.max?
      # Average per 5 minutes (unfortunately this is a bit slow)
      'aggregateWindow(every: 5m, fn: mean)'
    end
  end

  def second_aggregate
    if calc.sum?
      # Sum up the hours for the given period
      'sum'
    elsif calc.max?
      # Calc maximum for the given period
      'max'
    end
  end

  def build_query(start:, stop:, window:, limit:, offset:)
    return <<~QUERY if sensor == :house_power
      import "timezone"

      house = #{from_bucket}
        |> #{range(start:, stop:)}
        |> #{filter(selected_sensors: [:house_power])}
        |> #{first_aggregate_window}
        |> aggregateWindow(every: #{window}, offset: #{offset}, fn: #{second_aggregate}, location: #{location})
        |> filter(fn: (r) => r._value > 0)
        |> map(fn: (r) => ({ _time: r._time, _field: "housePower", _value: r._value }))

      heatpump = #{from_bucket}
        |> #{range(start:, stop:)}
        |> #{filter(selected_sensors: [:heatpump_power])}
        |> #{first_aggregate_window}
        |> aggregateWindow(every: #{window}, offset: #{offset}, fn: #{second_aggregate}, location: #{location})
        |> filter(fn: (r) => r._value > 0)
        |> map(fn: (r) => ({ _time: r._time, _field: "heatpumpPower", _value: r._value }))

      union(tables: [house, heatpump])
        |> pivot(rowKey:["_time"], columnKey: ["_field"], valueColumn: "_value")
        |> map(fn: (r) => ({
            _time: r._time,
            _value: r.housePower - (if exists r.heatpumpPower then r.heatpumpPower else 0.0)
        }))
        |> sort(columns: ["_value"], desc: #{desc})
        |> limit(n: #{limit})
    QUERY

    <<~QUERY
      import "timezone"

      #{from_bucket}
        |> #{range(start:, stop:)}
        |> #{filter}
        |> #{first_aggregate_window}
        |> aggregateWindow(every: #{window}, offset: #{offset}, fn: #{second_aggregate}, location: #{location})
        |> filter(fn: (r) => r._value > 0)
        |> sort(columns: ["_value"], desc: #{desc})
        |> limit(n: #{limit})
    QUERY
  end
end
