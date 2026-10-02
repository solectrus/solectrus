# Car::DailyRates gives each day of a car the rates of the window around it:
# the day plus MARGIN_DAYS on each side. The battery sits between charging and
# driving, so the car drives on energy that it charged on other days, and a
# day alone gives a wrong rate (see Car::Balance for the rationale). In the
# past, the window sits in the center, so a winter day keeps winter data. A
# window that reaches beyond today ends today.
#
# Each day drives its distance at the rates of its own window. The driving of
# a period is the sum of its days, so the driving cost and the driven energy
# add up: the days give the month, and the months give the year. A rate of a
# period is this sum divided by the distance. Several cars add up, each day
# of a car at the rates of its own window.
#
# A window with less than MIN_DISTANCE or without charged energy gives no
# rate, because a single charge would decide it. Such a day has no driving
# cost, and its distance does not count for a rate. A window with a session
# without a cost gives no cost rate, because its cost is too small.
#
# The distance comes from the daily summaries of the odometer of the car. The
# energy and the cost come from the charging sessions of the car, without a
# proportional calculation: the detection stores the energy, the grid share
# and the cost of each wallbox session (see ChargingSession::Detection), and
# the user enters each offsite session. A guest session and a session that is
# not assigned belong to no car, so they count for no car. A session belongs
# to the local date of its start.
class Car::DailyRates
  # Days on each side of a day. Long enough that charge-vs-drive imbalance
  # (battery SoC) averages out, short enough to keep the season and to fix a
  # recent rate soon (see docs/cars.md for the measurement).
  MARGIN_DAYS = 14
  public_constant :MARGIN_DAYS

  MIN_DISTANCE = 100
  public_constant :MIN_DISTANCE

  # The driving of a date range. The distance holds only the days with an
  # energy rate, and the cost distance only the days with a cost rate.
  Totals =
    Data.define(:distance, :energy_wh, :cost_distance, :cost) do
      def self.empty = new(distance: 0.0, energy_wh: 0.0, cost_distance: 0.0, cost: 0.0)

      def +(other)
        Totals.new(
          distance: distance + other.distance,
          energy_wh: energy_wh + other.energy_wh,
          cost_distance: cost_distance + other.cost_distance,
          cost: cost + other.cost,
        )
      end

      def rated?
        distance.positive?
      end

      def cost_rated?
        cost_distance.positive?
      end

      # Energy is in Wh, so /10 turns Wh per km into kWh per 100 km
      def consumption_per_100km
        (energy_wh / 10.0).fdiv(distance) if rated?
      end

      def cost_per_100km
        (cost * 100.0).fdiv(cost_distance) if cost_rated?
      end
    end
  public_constant :Totals

  # The daily values that a window adds up
  KEYS = %i[distance energy_wh cost uncosted].freeze
  private_constant :KEYS

  def initialize(timeframe, cars)
    @timeframe = timeframe
    @cars = cars
  end

  # The driving of the given dates, by default all dates of the timeframe. A
  # date outside the timeframe counts as empty.
  def totals(range = dates)
    range.filter_map { days[it] }.sum(Totals.empty)
  end

  # The days that the rates read without a fresh summary or without a
  # detection (see Summary.missing_or_stale_days). Without a car there is
  # nothing to read.
  def missing_or_stale_days
    return [] unless reach

    Summary.missing_or_stale_days(from: reach.begin, to: reach.end, charging_sessions: true)
  end

  private

  attr_reader :timeframe, :cars

  def dates
    @dates ||= timeframe.effective_beginning_date..timeframe.effective_ending_date
  end

  # { date => Totals of the cars, or nil without a rate }
  def days
    @days ||= dates.index_with { |date| cars.filter_map { day(it, date) }.presence&.sum(Totals.empty) }
  end

  # The driving of a car on a date at the rates of the window around it, or
  # nil without a rate
  def day(car, date)
    return unless bounds(car).cover?(date)

    distance = sum(car, date..date, :distance)
    return unless distance.positive?

    window = window(date..date, car)
    window_distance = sum(car, window, :distance)
    window_energy_wh = sum(car, window, :energy_wh)
    return if window_distance < MIN_DISTANCE || !window_energy_wh.positive?

    cost_distance = sum(car, window, :uncosted).zero? ? distance : 0.0
    Totals.new(
      distance:,
      energy_wh: distance * (window_energy_wh / window_distance),
      cost_distance:,
      cost: cost_distance * (sum(car, window, :cost) / window_distance),
    )
  end

  # The days that a window of the car can hold: from the installation date
  # to today, inside the period of use of the car. Each window ends at these
  # bounds, so the rate of a new car holds no energy of the car before it.
  def bounds(car)
    (@bounds ||= {})[car.id] ||=
      [timeframe.min_date, car.active_from].compact.max..[Date.current, car.active_until].compact.min
  end

  # The given dates plus MARGIN_DAYS on each side, inside the bounds of the car
  def window(range, car)
    bounds = bounds(car)
    [range.begin - MARGIN_DAYS, bounds.begin].compact.max..[range.end + MARGIN_DAYS, bounds.end].min
  end

  # The days that the rates of a car read: the window of the dates
  def span(car)
    (@spans ||= {})[car.id] ||= window(dates, car)
  end

  # The days that the rates of all cars read, or nil without any
  def reach
    return @reach if defined?(@reach)

    windows = cars.map { span(it) }.reject { it.begin > it.end }
    @reach = (windows.map(&:begin).min..windows.map(&:end).max if windows.any?)
  end

  # The sum of a daily value of a car over a range inside its span. It is the
  # difference of two running sums, so the window of each day of a long period
  # costs no loop over its days.
  def sum(car, range, key)
    first = span(car).begin
    sums = running_sums(car)[key]
    sums[(range.end - first).to_i + 1] - sums[(range.begin - first).to_i]
  end

  # { key => [0, day 1, day 1 + day 2, ...] } over the span of the car
  def running_sums(car)
    (@running_sums ||= {})[car.id] ||=
      begin
        rows = span(car).map { daily_values(car, it) }
        KEYS.index_with { |key| rows.each_with_object([0]) { |row, sums| sums << (sums.last + row[key]) } }
      end
  end

  def daily_values(car, date)
    sessions = sessions_by_day.dig(car.id, date) || []
    {
      distance: distances.dig(car.id, date) || 0.0,
      energy_wh: sessions.sum(&:kwh).to_f * 1000.0,
      cost: sessions.sum { it.cost.to_f },
      uncosted: sessions.count { it.cost.nil? },
    }
  end

  # { car id => { date => distance } } of the odometers, in one query
  def distances
    @distances ||=
      begin
        car_ids = cars.to_h { [Sensor::Cars.sensor_name(:car_mileage, it.id).to_s, it.id] }
        SummaryValue
          .where(date: reach, field: car_ids.keys, aggregation: :sum)
          .pluck(:field, :date, :value)
          .group_by(&:first)
          .to_h { |field, rows| [car_ids[field], rows.to_h { |_, date, value| [date, value] }] }
      end
  end

  # { car id => { local date => [session, ...] } }, in one query
  def sessions_by_day
    @sessions_by_day ||=
      ChargingSession
        .of_cars(cars)
        .in_range(reach.begin.beginning_of_day, reach.end.end_of_day)
        .group_by(&:car_id)
        .transform_values { it.group_by(&:date) }
  end
end
