# Finds the charging sessions of the own wallbox in its power curve, as one
# more step of the daily build (see Sensor::Summarizer). A detected session
# comes from the InfluxDB data of one day, like a daily summary, so a charge
# over midnight becomes two sessions.
#
# A session is a continuous period with wallbox_power > 0, found on the
# 5-minute means that Sensor::Query::Series builds for the charts. A gap of
# GAP or less does not end it, because load management and PV surplus
# control make such gaps. wallbox_car_connected bridges a longer gap, but it
# never moves an end: the first bucket with power is the start, and the last
# is the end. Otherwise a charge before the sensor reports the connection
# loses its energy, and the balance of the day breaks.
#
# The energy comes from integral(unit: 1h) over the raw series, the function
# of the daily sum, and not from the 5-minute means, which lose the shape
# inside a bucket. The grid share comes from wallbox_power_grid in the same
# way. A session below MIN_KWH is the standby power of the wallbox, and its
# energy stays in the wallbox sums.
#
# The grid share costs the electricity price and the PV share the feed-in
# price of the day. The session stores the cost of its grid share as well, so
# its split needs no price when it is read. Without the power splitter there
# is no grid share, and the full energy gets the electricity price. Without a
# price there is no cost, because zero is a wrong number.
#
# The detection runs in two steps: #call queries InfluxDB outside the
# transaction of the build, and #persist writes inside it (see
# ChargingSession::Detection::Persistence). The car of each session comes from
# ChargingSession::Detection::CarAssignment.
class ChargingSession::Detection
  # Bump to build the sessions of each day again
  VERSION = 1
  public_constant :VERSION

  BUCKET = 5.minutes
  private_constant :BUCKET

  # A gap of this length or less does not end a session
  GAP = 15.minutes
  public_constant :GAP

  MIN_KWH = 0.1
  public_constant :MIN_KWH

  WALLBOX_CURVES = %i[wallbox_power wallbox_car_connected].freeze
  private_constant :WALLBOX_CURVES

  WALLBOX_POWER = %i[wallbox_power wallbox_power_grid].freeze
  private_constant :WALLBOX_POWER

  Session = Data.define(:started_at, :ended_at, :kwh, :kwh_grid, :cost, :cost_grid, :car_id)
  public_constant :Session

  # SOLECTRUS reads the curves only when the wallbox has a configuration
  def self.enabled?
    Sensor::Config.configured?(:wallbox_power)
  end

  def initialize(dates)
    @dates = dates
  end

  attr_reader :dates

  # Reads the cars and the prices, so #call needs no database and can run in
  # a thread of its own, next to the build of the summaries
  def preload
    assignment
    prices.at(:electricity, Date.current)
    self
  end

  # { date => [Session, ...] }, without a write
  def call
    return dates.index_with { [] } unless self.class.enabled?

    found = dates.index_with { |date| find_periods(date) }
    energies = integrals(found.values.flatten(1))

    found.to_h do |date, periods|
      [date, periods.filter_map { |from, to| session(date, from, to, *energies[[from, to]]) }]
    end
  end

  # Writes the result of #call
  def persist(results)
    Persistence.new(assignment).call(results)
  end

  private

  def session(date, from, to, kwh, kwh_grid)
    return unless kwh && kwh >= MIN_KWH

    kwh_grid = kwh_grid&.clamp(0, kwh)
    cost, cost_grid = costs(date, kwh, kwh_grid)
    Session.new(
      started_at: from,
      ended_at: to,
      kwh: kwh.round(3),
      kwh_grid: kwh_grid&.round(3),
      cost:,
      cost_grid:,
      car_id: assignment.car_for(date, from, to)&.id,
    )
  end

  def assignment
    @assignment ||= CarAssignment.new(Car::Provisioning.call.to_a, curves: method(:curve))
  end

  # [[from, to], ...] of the day
  def find_periods(date)
    day = Timeframe.new(date.iso8601)

    curve(date, :wallbox_power).each_with_object([]) do |(stamp, watt), periods|
      next unless watt.positive?

      from = [stamp - BUCKET, day.beginning].max
      to = [stamp, day.ending].min
      last = periods.last

      if last && bridged?(date, last[1], from)
        last[1] = to
      else
        periods << [from, to]
      end
    end
  end

  def bridged?(date, last_end, next_start)
    return true if next_start - last_end <= GAP

    connected = curve(date, :wallbox_car_connected).select { |time, _| time > last_end && time - BUCKET < next_start }
    connected.any? && connected.all? { it.last.positive? }
  end

  def curve(date, sensor_name)
    curves.dig(date, sensor_name) || []
  end

  # The curves the detection needs, for Influx::DailyCurves. The curves of the
  # cars only on a day with more than one car in use, because the heuristics
  # read them only then.
  def curve_requests
    [
      { sensor_names: WALLBOX_CURVES.select { Sensor::Config.configured?(it) } },
      {
        sensor_names: assignment.sensor_names(dates),
        margin: ChargingSession::Detection::CarAssignment::READING_DISTANCE,
      },
    ]
  end

  def curves
    @curves ||= Sensor::Query::Helpers::Influx::DailyCurves.new(dates, curve_requests).call
  end

  # { [from, to] => [kWh, kWh of the grid or nil] }, from one program for all
  # sessions of the chunk
  def integrals(periods)
    return {} if periods.empty?

    names = WALLBOX_POWER.select { Sensor::Config.configured?(it) }
    by_session = Influx.query(integral_flux(periods, names)).group_by { it['session'].to_i }
    lookup = Sensor::Query::Helpers::Influx::SensorFilter.lookup(names)

    periods.each_with_index.to_h do |period, index|
      values = (by_session[index] || []).to_h { [lookup[[it['_measurement'], it['_field']]], it['_value'].to_f / 1000.0] }
      [period, values.values_at(*WALLBOX_POWER)]
    end
  end

  def integral_flux(periods, names)
    predicate = Sensor::Query::Helpers::Influx::SensorFilter.predicate(names)
    streams =
      periods.each_with_index.map do |(from, to), index|
        <<~FLUX
          i#{index} = from(bucket: "#{Rails.configuration.x.influx.bucket}")
            |> range(start: #{from.iso8601}, stop: #{to.iso8601})
            |> filter(fn: #{predicate})
            |> integral(unit: 1h)
            |> set(key: "session", value: "#{index}")
            |> keep(columns: ["_value", "_field", "_measurement", "session"])
        FLUX
      end
    names = Array.new(periods.size) { "i#{it}" }

    "#{streams.join}\n#{names.one? ? names.first : "union(tables: [#{names.join(', ')}])"}"
  end

  # [cost, cost of the grid share]. The cost of the PV share is the rest, so
  # the parts add up to the cost.
  def costs(date, kwh, kwh_grid)
    electricity = prices.at(:electricity, date)
    return [nil, nil] unless electricity
    return [(kwh * electricity).round(2), nil] unless kwh_grid

    feed_in = prices.at(:feed_in, date)
    return [nil, nil] unless feed_in

    grid = kwh_grid * electricity
    [(grid + ((kwh - kwh_grid) * feed_in)).round(2), grid.round(2)]
  end

  def prices
    @prices ||= Price::Schedule.new
  end
end
