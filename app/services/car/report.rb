# The numbers of the selected cars in a timeframe of a day or longer: the
# charging of the period, its driving and the distance. The car page and its
# charts read the same report, the page for the whole timeframe and a chart
# for each column.
#
# The charged energy and the charging cost are the sums of the charging
# sessions of the selected cars. A guest session and a session that is not
# assigned count for no car. The selection "all" is therefore the sum of the
# cars, and not the sum of the wallbox.
#
# The driving cost and the two rates come from the window around each day
# (see Car::Driving), so they read the days around the timeframe too. These
# days need a summary (see .pending_days).
class Car::Report
  # A source of the charged energy with its energy (kWh) and its cost
  Source = Data.define(:key, :kwh, :cost)
  public_constant :Source

  # The days that a report of the timeframe reads and that have no fresh
  # summary yet
  def self.pending_days(timeframe)
    reach = Car::Driving.reach(timeframe.effective_dates, min_date: timeframe.min_date)
    Summary.missing_or_stale_days(from: reach.begin, to: reach.end)
  end

  # The sources of the Sums of the wallbox and the offsite sessions, from the
  # bottom of a column up: PV and grid of the wallbox with the power
  # splitter, the wallbox alone without it, and the offsite sessions
  def self.sources_of(wallbox, offsite, split:)
    [
      *(split ? [Source.new(:pv, wallbox.kwh_pv, wallbox.cost_pv), Source.new(:grid, wallbox.kwh_grid, wallbox.cost_grid)] : [Source.new(:wallbox, wallbox.kwh, wallbox.cost)]),
      Source.new(:offsite, offsite.kwh, offsite.cost),
    ]
  end

  def initialize(timeframe, cars)
    @timeframe = timeframe
    @cars = cars
    @dates = timeframe.effective_dates
    @ledger = Car::Ledger.new(cars, Car::Driving.reach(dates, min_date: timeframe.min_date))
  end

  attr_reader :timeframe, :cars, :dates

  # The one car of the report, or nil for several. "all" of a single car is
  # that car, too.
  def car
    cars.sole if cars.one?
  end

  # The Sums of the sessions of the cars, of a kind (:wallbox, :offsite) or of
  # each kind
  def sessions(kind = nil, dates: self.dates)
    memo(:sessions, kind, dates) { ledger.sessions(dates, kind:) }
  end

  # The guest sessions belong to no car, so they are the same for each
  # selection, and their cost is a loss for the owner
  def guest_sessions
    memo(:guest_sessions) { ledger.guest_sessions(dates) }
  end

  # The wallbox sessions without a car. The selection "all" names them,
  # because a number that is too small without a reason is the one error the
  # page must not make.
  def unassigned_sessions
    memo(:unassigned_sessions) { ledger.unassigned_sessions(dates) }
  end

  # The number of the proposals of the cars (see ChargingSession::Proposal).
  # A proposal does not count, so the page only points to it. The page does
  # not wait for the step of the proposals, so the number can be behind.
  def proposal_count
    memo(:proposal_count) { ChargingSession.proposals.where(car_id: cars.map(&:id)).on_dates(dates).count }
  end

  # The sources of the charging of the dates (see .sources_of)
  def sources(dates: self.dates)
    memo(:sources, dates) { self.class.sources_of(sessions(:wallbox, dates:), sessions(:offsite, dates:), split: split?) }
  end

  # Whether the energy and the cost of the wallbox split into PV and grid.
  # Without the power splitter a wallbox session has no grid share.
  def split?
    memo(:split) { ApplicationPolicy.power_splitter? && sessions(:wallbox).split? }
  end

  # Whether a selected car has an odometer. Without one, the period has no
  # distance and no driving cost, but the charging still counts. A car with
  # an odometer and without a value in the period drives nothing (see
  # #distance).
  def driving?
    cars.any? { it.sensor?(:car_odometer) }
  end

  # The distance (km) of the cars, nil without a value
  def distance
    memo(:distance) { ledger.distance(dates) }
  end

  # The average distance of a day on which a selected car was in use. Only
  # meaningful for more than one day. The cheap checks come first, so a day
  # or a period without a distance counts no days.
  def km_per_day
    memo(:km_per_day) do
      next unless timeframe.days_passed > 1 && distance&.positive?

      days = days_in_use
      distance.fdiv(days) if days > 1
    end
  end

  # The average maximum range of one car. The cars of "all" have batteries of
  # their own, so their average says nothing.
  def max_range
    ledger.max_range(car, dates) if car
  end

  # The visits of the cars at the places in the timeframe, and the number of
  # these places (see PlaceVisit.counts)
  def visit_counts
    memo(:visit_counts) { PlaceVisit.where(car: cars).counts(timeframe) }
  end

  # The driving of the cars on the given dates, day by day at the rates of the
  # window around each day. Several cars are the sum of each car, so a chart
  # with a part for each car does not drive each day twice.
  def driving(dates = self.dates, cars: self.cars)
    memo(:driving, dates, cars.map(&:id)) do
      next rates.totals(dates, cars:) unless cars.many?

      Car::Driving::Totals.sum(cars.map { driving(dates, cars: [it]) })
    end
  end

  # The cost of the distance, the sum of its days. It differs from the
  # charging cost, because the battery holds energy that the car charged on
  # other days. Without a rate there is no driving cost.
  def driving_cost
    driving.cost if distance && driving.cost_rated?
  end

  # The value of a chart of the car page for its insights and its trend (see
  # Car::Trend), nil without one. The energy is in Wh, like a column of the
  # chart. Sessions without a price have no cost.
  def value(sensor_name) # rubocop:disable Metrics/CyclomaticComplexity
    case sensor_name
    when :car_distance then distance
    when :car_charging then sessions.kwh * 1000
    when :car_charging_costs then sessions.cost if sessions.cost?
    when :car_driving_costs then driving_cost
    when :car_cost_rate then driving.cost_per_100km
    when :car_consumption_rate then driving.consumption_per_100km
    when :car_max_range then max_range
    end
  end

  # [date, value] of the day with the highest distance, charged energy (Wh)
  # or driving cost, nil without one
  def maximum(sensor_name)
    case sensor_name
    when :car_distance then max_distance_day
    when :car_charging then max_charging_day
    when :car_driving_costs then max_driving_cost_day
    end
  end

  private

  attr_reader :ledger

  # The components of a page read the same numbers more than once, and each
  # number is a pass over the days, so it is computed once per key. A nil
  # is kept, too.
  def memo(*key)
    @memo ||= {}
    return @memo[key] if @memo.key?(key)

    @memo[key] = yield
  end

  # The daily distance is the sum of the cars on each day, so the database
  # finds the day
  def max_distance_day
    SummaryValue
      .where(field: cars.map { it.sensor_name(:car_odometer).to_s }, aggregation: 'sum', date: dates)
      .group(:date)
      .order(Arel.sql('SUM(value) DESC'))
      .pick(:date, Arel.sql('SUM(value)'))
  end

  # The energy of the sessions of the cars, without the guest sessions
  def max_charging_day
    date, kwh = ChargingSession.effective.where(car: cars).on_dates(dates).max_daily_kwh
    [date, kwh.to_f * 1000] if kwh
  end

  # The driving cost of a day comes from the rates of its window (see
  # Car::Driving), so it exists in Ruby only
  def max_driving_cost_day
    days =
      dates.filter_map do |date|
        day = rates.totals(date..date, cars:)
        [date, day.cost] if day.cost_rated?
      end
    days.max_by(&:last)
  end

  def rates
    @rates ||= Car::Driving.new(ledger, min_date: timeframe.min_date)
  end

  # The passed days of the period on which a selected car was in use. A car
  # outside its period of use drives nothing, so its days do not count. A
  # car counts from the first value of its odometer, so a later odometer
  # does not spread its distance over the days before it.
  def days_in_use
    passed = timeframe.days_passed
    return 0 if passed.zero?

    first = timeframe.effective_beginning_date
    (first..(first + passed - 1)).count { |date| cars.any? { in_use_with_odometer?(it, date) } }
  end

  def in_use_with_odometer?(car, date)
    since = odometer_since[car.id]
    car.active_on?(date) && since.present? && date >= since
  end

  # { car id => the date of the first value of its odometer }
  def odometer_since
    @odometer_since ||=
      SummaryValue
        .where(field: cars.map { it.sensor_name(:car_odometer).to_s }, aggregation: 'sum')
        .group(:field)
        .minimum(:date)
        .transform_keys { Sensor::Cars.number_of(it) }
  end
end
