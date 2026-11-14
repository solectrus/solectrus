# Finds the charging sessions of the own wallbox in its power curve, as one
# more step of the daily build (see Sensor::Summarizer). A detected session
# comes from the InfluxDB data of one day, like a daily summary, so a charge
# over midnight becomes two sessions.
#
# The period of a session comes from the 5-minute means that
# Sensor::Query::Series builds for the charts (see
# ChargingSession::Detection::Periods). The session stores the times of the
# readings at its edges (see ChargingSession::Detection::Edges).
#
# The energy comes from integral(unit: 1h) over the raw series, the function of
# the daily sum, and not from the 5-minute means, which lose the shape inside a
# bucket. The grid share comes from wallbox_power_grid in the same way, unless
# the power splitter has not split the end of the session yet (see
# #kwh_grid). A session below MIN_SESSION_KWH is the standby power of the
# wallbox, and its energy stays in the wallbox sums.
#
# A session gets the prices of its day (see ChargingSession::Cost). It stores
# the cost of its grid share as well, so its split needs no price when it is
# read.
#
# The detection runs in two steps: #call queries InfluxDB outside the
# transaction of the build, and #persist writes inside it (see
# ChargingSession::Detection::Persistence). The car of each session comes from
# ChargingSession::Detection::CarAssignment, and the state of charge of each
# candidate car from ChargingSession::Detection::StateOfCharge. The cars, the
# prices and the
# home are read when the detection is made, so #call needs no database and
# can run in a thread of its own, next to the build of the summaries.
class ChargingSession::Detection
  # The step of the daily build (see Summary::Steps)
  KEY = :charging_sessions
  public_constant :KEY

  # Bump to build each day again (see Summary::Steps)
  VERSION = 2
  public_constant :VERSION

  # The sessions keep the changes of the user, so a reset of the summaries
  # keeps them (see Summary::Steps)
  def self.derived = nil

  WALLBOX_POWER = %i[wallbox_power wallbox_power_grid].freeze
  private_constant :WALLBOX_POWER

  # The Power Splitter writes one value per cycle, in the middle of the
  # cycle. A session starts and ends between two values, so the integral of
  # its grid share reaches one cycle beyond each end, within its day.
  # Otherwise the session loses the grid share of its first and its last
  # cycle, which the daily sum holds. Two sessions are more than two cycles
  # apart (see Car::Rules::MAX_SESSION_GAP), so no value counts twice.
  SPLITTER_CYCLE = 5.minutes
  private_constant :SPLITTER_CYCLE

  Session = Data.define(:started_at, :ended_at, :kwh, :kwh_grid, :cost, :cost_grid, :car_id, :socs)
  public_constant :Session

  # SOLECTRUS reads the curves only when the wallbox has a configuration
  def self.enabled?
    Sensor::Config.configured?(:wallbox_power)
  end

  # The energy, the periods, and the car and its state of charge
  def self.sensor_names = [*WALLBOX_POWER, *ChargingSession::Curves::WALLBOX, *ChargingSession::Curves.car_sensor_names]

  # `curves` are the curves of the wallbox and of the cars, which the
  # proposals of the offsite sessions read as well (see
  # ChargingSession::Curves)
  def initialize(dates, cars: Car.configured, prices: Price::Schedule.new, curves: ChargingSession::Curves.new(dates, cars:))
    @dates = dates
    @cars = cars
    @curves = curves
    @cost = ChargingSession::Cost.new(prices)
    @assignment = CarAssignment.new(cars, curves: method(:curve), home: Place.home)
    @state_of_charge = StateOfCharge.new(cars, curves: method(:curve))
  end

  attr_reader :dates

  # { date => [Session, ...] }, without a write
  def call
    return dates.index_with { [] } unless self.class.enabled?

    curves.start
    found = dates.index_with { |date| periods(date) }
    spans = found.values.flatten(1).map { [it.from, it.to] }
    reading_edges = Concurrent::Promises.future { Edges.new(spans).call }
    energies = integrals(spans)
    edges = reading_edges.value!

    found.to_h do |date, periods|
      [date, periods.filter_map { session(date, it.from, it.to, *energies[[it.from, it.to]], edges: edges[[it.from, it.to]]) }]
    end
  end

  # Writes the result of #call
  def persist(results)
    Persistence.new.call(results)
  end

  private

  attr_reader :cars, :cost, :assignment, :state_of_charge, :curves

  # The car and its state of charge read the buckets of the period, and the
  # session stores the times of the readings at its edges
  def session(date, from, to, kwh, kwh_grid, edges: nil)
    return unless kwh && kwh >= Car::Rules::MIN_SESSION_KWH

    # The cost comes from the stored energy, so a change of a price gives the
    # same cost (see ChargingSession.reprice)
    kwh = kwh.round(3)
    kwh_grid = kwh_grid(date, from, to, kwh, kwh_grid)&.clamp(0, kwh)&.round(3)
    session_cost, cost_grid = cost.call(date, kwh, kwh_grid)
    started_at, ended_at = edges || [from, to]
    Session.new(
      started_at:,
      ended_at:,
      kwh:,
      kwh_grid:,
      cost: session_cost,
      cost_grid:,
      car_id: assignment.car_for(date, from, to)&.id,
      socs: state_of_charge.call(date, from, to),
    )
  end

  # The periods of the day (see Periods::Period)
  def periods(date) = Periods.of(curves, date).call

  # The curve of a wallbox sensor or of a car sensor on a day
  def curve(date, sensor_name)
    source = ChargingSession::Curves::WALLBOX.include?(sensor_name) ? curves.wallbox : curves.cars
    source.dig(date, sensor_name) || []
  end

  # The power splitter writes its split some minutes after the power. On the
  # running day, the curve of the grid share therefore lacks the buckets at
  # the end of a running charge, and the integral would count them as PV,
  # also at night. Such a session takes the grid share of the buckets that
  # the power splitter split already, and none before the first one. The
  # first build after the power splitter caught up takes the integral again.
  def kwh_grid(date, from, to, kwh, integral)
    split = pending_split(date, from, to)
    return integral unless split

    power = curve(date, :wallbox_power).to_h
    total = split.sum { |time, _| power.fetch(time, 0.0) }
    kwh * split.sum(&:last) / total if total.positive?
  end

  # The split buckets of a session on the running day, while the power
  # splitter has not split its last one
  def pending_split(date, from, to)
    split = curves.wallbox.dig(date, :wallbox_power_grid)&.select { |time, _| time > from }
    split if split&.none? { |time, _| time >= to }
  end

  # { [from, to] => [kWh, kWh of the grid or nil] }, from one program for all
  # sessions of the chunk
  def integrals(periods)
    return {} if periods.empty?

    names = WALLBOX_POWER.select { Sensor::Config.configured?(it) }
    rows = Sensor::Query::Helpers::Influx::FluxProgram.query(integral_flux(periods, names), class_name: self.class.name, sensors: names)
    by_session = rows.group_by { it['session'].to_i }
    lookup = Sensor::Query::Helpers::Influx::SensorFilter.lookup(names)

    periods.each_with_index.to_h do |period, index|
      values = (by_session[index] || []).each_with_object({}) do |row, hash|
        lookup[[row['_measurement'], row['_field']]].each { hash[it] = row['_value'].to_f / 1000.0 }
      end
      [period, values.values_at(*WALLBOX_POWER)]
    end
  end

  # One stream for each session and sensor, because the grid share reads a
  # wider window (see SPLITTER_CYCLE)
  def integral_flux(periods, names)
    program = Sensor::Query::Helpers::Influx::FluxProgram
    filter = Sensor::Query::Helpers::Influx::SensorFilter
    streams =
      periods.each_with_index.flat_map do |(from, to), index|
        names.each_with_index.map do |name, part|
          start, stop = name == :wallbox_power_grid ? splitter_window(from, to) : [from, to]
          <<~FLUX
            i#{index}_#{part} = source(#{program.range_args(start, stop)})
              |> filter(fn: f#{part})
              |> integral(unit: 1h)
              |> set(key: "session", value: "#{index}")
              |> keep(columns: ["_value", "_field", "_measurement", "session"])
          FLUX
        end
      end

    <<~FLUX
      #{program.source(filter.predicate(names))}
      #{names.each_with_index.map { |name, part| "f#{part} = #{filter.predicate([name])}" }.join("\n")}
      #{streams.join}
      #{program.union(Array.new(periods.size) { |index| names.each_index.map { "i#{index}_#{it}" } }.flatten)}
    FLUX
  end

  # The window of the grid share of a session (see SPLITTER_CYCLE)
  def splitter_window(from, to)
    day = from.in_time_zone.all_day
    [[from - SPLITTER_CYCLE, day.begin].max, [to + SPLITTER_CYCLE, day.end].min]
  end
end
