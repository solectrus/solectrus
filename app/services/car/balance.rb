# Car::Balance wraps a Sensor::Data::Single object and exposes the numbers of
# the car page for the selected cars (see CarSelectable): the distance, the
# charged energy and the charging cost, and the driving cost with the two
# rates per 100 km.
#
# Distance comes from the odometer of each car, which stores the daily driven
# kilometers. Summing them over any period yields the total distance.
#
# The charged energy and the charging cost are the sums of the charging
# sessions of the selected cars, without a proportional calculation. A guest
# session and a session that is not assigned count for no car. The selection
# "all" is therefore the sum of the cars, and not the sum of the wallbox, and
# it names the energy of the sessions that are not assigned.
#
# Decoupling charging from driving:
# Charging (energy in) and driving (energy out) are separated in time by the
# battery acting as a buffer. Dividing the energy charged *within the period*
# by the distance driven *within the period* therefore breaks down for short
# timeframes: a day on which the car is driven but not charged would show a
# cost of 0, while a day with charging but no driving would explode.
# To keep the per-100km efficiency figures stable and meaningful, each day
# takes the rates of a window around it (see Car::DailyRates). Over such a
# window charged energy closely tracks the energy actually driven, because
# the battery's state of charge nets out. The driving of a period is the sum
# of its days, so the driving cost adds up like any other cost. The absolute
# energy/cost cards stay period-accurate.
class Car::Balance
  # The live values of one car
  Live = Data.define(:car, :soc, :range, :max_range, :odometer)
  public_constant :Live

  def initialize(sensor_data, cars:)
    raise ArgumentError unless sensor_data.is_a?(Sensor::Data::Single)

    @sensor_data = sensor_data
    @cars = cars
  end

  attr_reader :cars

  # The one car of the page, or nil for several. "all" of a single car is
  # that car, too.
  def car
    cars.sole if cars.one?
  end

  delegate_missing_to :@sensor_data

  # The live values of each selected car
  def live
    cars.map do |car|
      Live.new(
        car:,
        soc: value(:car_battery_soc, car.id),
        range: value(:car_range, car.id),
        max_range: value(:car_max_range, car.id),
        odometer: value(:car_mileage, car.id),
      )
    end
  end

  %i[wallbox_power wallbox_car_connected].each do |sensor_name|
    define_method(sensor_name) do
      @sensor_data.public_send(sensor_name) if @sensor_data.respond_to?(sensor_name)
    end
  end

  # The driving of the period, day by day at the rates of the window around
  # each day. It gives the rates and the driving cost.
  def driving
    @driving ||= Car::DailyRates.new(timeframe, cars).totals
  end

  # Total kilometers driven in the period by the selected cars. For "now"
  # there is no period, so the value is meaningful only for range queries.
  def car_distance
    return if timeframe.now?

    values = cars.filter_map { value(:car_mileage, it.id) }
    values.sum if values.any?
  end

  # The average maximum range of one car. The cars of "all" have batteries
  # of their own, so their average says nothing.
  def car_max_range
    value(:car_max_range, car.id) if car
  end

  # Average kilometers driven per day in the period.
  # Only meaningful for multi-day timeframes.
  def car_km_per_day
    days = timeframe.days_passed
    return if days <= 1
    return unless car_distance&.positive?

    car_distance.fdiv(days)
  end

  # Cost per 100 kilometers driven: the driving cost divided by the distance
  # of the days with a cost rate. The rate of each day comes from the window
  # around it, so the figure stays stable and non-zero even on days with
  # driving but no charging. See class comment for the rationale.
  delegate :cost_per_100km, to: :driving, prefix: :car

  # kWh per 100 kilometers driven, from the rate of each day like the cost
  # per 100 km. See class comment for the rationale.
  delegate :consumption_per_100km, to: :driving, prefix: :car

  # Cost of the distance driven in the period, the sum of its days. It differs
  # from the charging cost of the period (#charging_costs), because the
  # battery holds energy that the car charged on other days. Without a rate
  # there is no driving cost.
  def car_driving_costs
    driving.cost if car_distance && driving.cost_rated?
  end

  # The charged energy of the selected cars (Wh), at the wallbox and offsite
  def charged_wh
    sessions.sum { it.kwh.to_f } * 1000.0
  end

  # The charging cost of the selected cars, or nil without a session
  def charging_costs
    sessions.sum { it.cost.to_f } if sessions.any?
  end

  # Whether each session of the period has a cost. A wallbox session has no
  # cost on a day without a price.
  def charging_costs_complete?
    sessions.none? { it.cost.nil? }
  end

  def charge_split
    @charge_split ||= Car::ChargeSplit.new(sessions)
  end

  # { count:, wh:, cost: } of the sessions of a kind, the cost nil without a
  # session:
  #
  # - :wallbox and :offsite, the sessions of the selected cars
  # - :guest, the guest sessions of the period. They belong to no car, so they
  #   are the same for each selection, and their cost is a loss for the owner.
  # - :not_assigned, the wallbox sessions of the period without a car. The
  #   selection "all" names them, because a number that is too small without
  #   a reason is the one error the page must not make.
  def session_totals(kind)
    (@session_totals ||= {})[kind] ||= build_session_totals(kind)
  end

  private

  def build_session_totals(kind)
    case kind
    when :wallbox then totals_of(sessions.select(&:wallbox?))
    when :offsite then totals_of(sessions.select(&:offsite?))
    when :guest then query_totals(ChargingSession.wallbox.where(guest: true))
    when :not_assigned then query_totals(ChargingSession.not_assigned)
    end
  end

  def totals_of(sessions)
    {
      count: sessions.size,
      wh: sessions.sum { it.kwh.to_f } * 1000.0,
      cost: (sessions.sum { it.cost.to_f } if sessions.any?),
    }
  end

  def query_totals(scope)
    totals = scope.in_range(*period).totals
    { count: totals[:count], wh: totals[:kwh] * 1000.0, cost: (totals[:cost] if totals[:count].positive?) }
  end

  def value(role, number)
    name = Sensor::Cars.sensor_name(role, number)
    @sensor_data.public_send(name) if @sensor_data.respond_to?(name)
  end

  def sessions
    @sessions ||= ChargingSession.of_cars(cars).in_range(*period).to_a
  end

  def period
    [timeframe.beginning, timeframe.ending]
  end
end
