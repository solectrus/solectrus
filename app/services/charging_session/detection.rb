# Finds the charging sessions of the own wallbox in its power curve, as one
# more step of the daily build (see Sensor::Summarizer). A detected session
# comes from the InfluxDB data of one day, like a daily summary, so a charge
# over midnight becomes two sessions.
#
# The period of a session comes from the 5-minute means that
# Sensor::Query::Series builds for the charts (see
# ChargingSession::Detection::Periods).
#
# The energy comes from integral(unit: 1h) over the raw series, the function
# of the daily sum, and not from the 5-minute means, which lose the shape
# inside a bucket. The grid share comes from wallbox_power_grid in the same
# way. A session below MIN_KWH is the standby power of the wallbox, and its
# energy stays in the wallbox sums.
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

  # Bump to build the sessions of each day again
  VERSION = 1
  public_constant :VERSION

  # The sessions keep the changes of the user, so a reset of the summaries
  # keeps them (see Summary::Steps)
  def self.derived = nil

  MIN_KWH = 0.1
  public_constant :MIN_KWH

  WALLBOX_POWER = %i[wallbox_power wallbox_power_grid].freeze
  private_constant :WALLBOX_POWER

  Session = Data.define(:started_at, :ended_at, :kwh, :kwh_grid, :cost, :cost_grid, :car_id, :socs)
  public_constant :Session

  # SOLECTRUS reads the curves only when the wallbox has a configuration
  def self.enabled?
    Sensor::Config.configured?(:wallbox_power)
  end

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
    energies = integrals(found.values.flatten(1))

    found.to_h do |date, periods|
      [date, periods.filter_map { |from, to| session(date, from, to, *energies[[from, to]]) }]
    end
  end

  # Writes the result of #call
  def persist(results)
    Persistence.new.call(results)
  end

  private

  attr_reader :cars, :cost, :assignment, :state_of_charge, :curves

  def session(date, from, to, kwh, kwh_grid)
    return unless kwh && kwh >= MIN_KWH

    # The cost comes from the stored energy, so a change of a price gives the
    # same cost (see ChargingSession.reprice)
    kwh = kwh.round(3)
    kwh_grid = kwh_grid&.clamp(0, kwh)&.round(3)
    session_cost, cost_grid = cost.call(date, kwh, kwh_grid)
    Session.new(
      started_at: from,
      ended_at: to,
      kwh:,
      kwh_grid:,
      cost: session_cost,
      cost_grid:,
      car_id: assignment.car_for(date, from, to)&.id,
      socs: state_of_charge.call(date, from, to),
    )
  end

  # [[from, to], ...] of the day
  def periods(date)
    Periods.new(date, power: curve(date, :wallbox_power), connected: curve(date, :wallbox_car_connected)).call
  end

  # The curve of a wallbox sensor or of a car sensor on a day
  def curve(date, sensor_name)
    source = ChargingSession::Curves::WALLBOX.include?(sensor_name) ? curves.wallbox : curves.cars
    source.dig(date, sensor_name) || []
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

  def integral_flux(periods, names)
    program = Sensor::Query::Helpers::Influx::FluxProgram
    streams =
      periods.each_with_index.map do |(from, to), index|
        <<~FLUX
          i#{index} = source(#{program.range_args(from, to)})
            |> integral(unit: 1h)
            |> set(key: "session", value: "#{index}")
            |> keep(columns: ["_value", "_field", "_measurement", "session"])
        FLUX
      end

    <<~FLUX
      #{program.source(Sensor::Query::Helpers::Influx::SensorFilter.predicate(names))}
      #{streams.join}
      #{program.union(Array.new(periods.size) { "i#{it}" })}
    FLUX
  end
end
