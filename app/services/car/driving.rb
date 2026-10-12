# The driving of the cars: each day drives its distance at the rates of a
# window around it, the day plus MARGIN_DAYS on each side (docs/cars.md).
#
# The battery sits between charging and driving, so the car drives on energy
# that it charged on other days, and a day alone gives a wrong rate. In the
# past, the window sits in the center, so a winter day keeps winter data.
#
# The driving of a period is the sum of its days, so the driving cost and
# the driven energy add up: the days give the month, and the months give the
# year. A rate of a period is this sum divided by its distance. Several cars
# add up, each day of a car at the rates of its own window.
#
# A window with less than MIN_DISTANCE or without charged energy gives no
# rate, because a single charge would decide it. Such a day has no driving
# cost, and its distance does not count for a rate. A window with a session
# without a cost gives no cost rate, because its cost is too small.
class Car::Driving
  # Long enough that the change of the battery content is a small error,
  # short enough to keep the season and to fix a recent rate soon
  MARGIN_DAYS = 14
  public_constant :MARGIN_DAYS

  MIN_DISTANCE = 100
  public_constant :MIN_DISTANCE

  # The driving of a set of days. The distance holds only the days with an
  # energy rate, and the cost distance only the days with a cost rate.
  Totals =
    Data.define(:distance, :energy_wh, :cost_distance, :cost) do
      def self.empty = new(distance: 0.0, energy_wh: 0.0, cost_distance: 0.0, cost: 0.0)

      # The sum of a list of Totals in one pass
      def self.sum(list)
        return empty if list.empty?

        new(**members.index_with { |member| list.sum(&member) })
      end

      def rated? = distance.positive?

      def cost_rated? = cost_distance.positive?

      # Energy is in Wh, so /10 turns Wh per km into kWh per 100 km
      def consumption_per_100km
        (energy_wh / 10.0).fdiv(distance) if rated?
      end

      def cost_per_100km
        (cost * 100.0).fdiv(cost_distance) if cost_rated?
      end
    end
  public_constant :Totals

  # The dates that the windows of the given dates read: MARGIN_DAYS more on
  # each side, from the first date of the installation to today
  def self.reach(dates, min_date:)
    [dates.begin - MARGIN_DAYS, min_date].compact.max..[dates.end + MARGIN_DAYS, Date.current].min
  end

  # The ledger must hold the reach of each date to ask for
  def initialize(ledger, min_date:)
    @ledger = ledger
    @min_date = min_date
  end

  # The driving of the given cars of the ledger on the given dates. A car
  # drives only on the dates inside its bounds.
  def totals(dates, cars: ledger.cars)
    Totals.sum(
      cars.flat_map do |car|
        from = [dates.begin, bounds(car).begin].max
        to = [dates.end, bounds(car).end].min
        from > to ? [] : (from..to).filter_map { day(car, it) }
      end,
    )
  end

  private

  attr_reader :ledger, :min_date

  # The driving of a car on a date at the rates of its window, or nil without
  # a rate
  def day(car, date)
    distance = ledger.daily_distance(car, date)
    return unless distance.positive?

    window = window(car, date)
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

  # The days that a window of the car can hold: from the first date of the
  # installation to today, inside the period of use of the car. So the rate
  # of a new car holds no energy of the car before it.
  def bounds(car)
    (@bounds ||= {})[car.id] ||= [min_date, car.active_from].compact.max..[Date.current, car.active_until].compact.min
  end

  def window(car, date)
    [date - MARGIN_DAYS, bounds(car).begin].max..[date + MARGIN_DAYS, bounds(car).end].min
  end

  # The sum of a daily value of a car over a range of the ledger. It is the
  # difference of two running sums, so the window of each day of a long
  # period costs no loop over its days.
  def sum(car, range, key)
    first = ledger.dates.begin
    sums = running_sums(car)[key]
    sums[(range.end - first).to_i + 1] - sums[(range.begin - first).to_i]
  end

  # { key => [0, day 1, day 1 + day 2, ...] } over the dates of the ledger
  def running_sums(car)
    (@running_sums ||= {})[car.id] ||=
      begin
        sums = { distance: [0.0], energy_wh: [0.0], cost: [0.0], uncosted: [0] }
        ledger.dates.each do |date|
          sessions = ledger.daily_sessions(car, date)
          add(sums[:distance], ledger.daily_distance(car, date))
          add(sums[:energy_wh], sessions.kwh * 1000.0)
          add(sums[:cost], sessions.cost)
          add(sums[:uncosted], sessions.uncosted)
        end
        sums
      end
  end

  def add(running, value) = running << (running.last + value)
end
