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
# The battery holds more at the end of a window than at its start, or less.
# The charged energy of the window is that much too high, or too low, so the
# change of the state of charge corrects it (see #driven_share).
#
# A window with less than MIN_DISTANCE or without charged energy gives no
# rate, because a single charge would decide it. The window then widens by
# MARGIN_DAYS on each side, up to MAX_MARGIN_DAYS, so a day between two
# charges far apart gets the rate of these charges. Without a rate in the
# widest window, the day has no driving cost, and its distance does not
# count for a rate. A window with a session without a cost gives no cost
# rate, because its cost is too small.
class Car::Driving
  # Long enough that the change of the battery content is a small error,
  # short enough to keep the season and to fix a recent rate soon
  MARGIN_DAYS = 14
  public_constant :MARGIN_DAYS

  # The margin of the widest window, for a car that drives little and
  # charges seldom
  MAX_MARGIN_DAYS = 3 * MARGIN_DAYS
  public_constant :MAX_MARGIN_DAYS

  MIN_DISTANCE = 100
  public_constant :MIN_DISTANCE

  # The dates that the windows of the given dates read: MAX_MARGIN_DAYS more
  # on each side, from the first date of the installation to today. The day
  # before the first window gives the state of charge at its start.
  def self.reach(dates, min_date:)
    [dates.begin - MAX_MARGIN_DAYS - 1, min_date].compact.max..[dates.end + MAX_MARGIN_DAYS, Date.current].min
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

  # The rates of a car per km at the window of a date: the energy (Wh), and
  # the cost, nil without a cost rate. Nil without an energy rate, also in
  # the widest window.
  Rate = Data.define(:energy_wh, :cost)
  public_constant :Rate

  def rate(car, date)
    MARGIN_DAYS.step(MAX_MARGIN_DAYS, MARGIN_DAYS) do |margin|
      rate = rate_of(car, window(car, date, margin))
      return rate if rate
    end
    nil
  end

  private

  attr_reader :ledger, :min_date

  # The rates of a window, nil without enough distance or charged energy
  def rate_of(car, window)
    window_distance = sum(car, window, :distance)
    charged_wh = sum(car, window, :energy_wh)
    return if window_distance < MIN_DISTANCE || !charged_wh.positive?

    share = driven_share(car, window, charged_wh) / window_distance
    Rate.new(energy_wh: charged_wh * share, cost: (sum(car, window, :cost) * share if sum(car, window, :uncosted).zero?))
  end

  # The driving of a car on a date at the rates of its window, or nil without
  # a rate
  def day(car, date)
    distance = ledger.daily_distance(car, date)
    return unless distance.positive?

    rate = rate(car, date)
    return unless rate

    cost_distance = rate.cost ? distance : 0.0
    Totals.new(distance:, energy_wh: distance * rate.energy_wh, cost_distance:, cost: cost_distance * rate.cost.to_f)
  end

  # The share of the charged energy of the window that the car drove on: the
  # charged energy less the energy that the battery holds more at the end of
  # the window. The cost takes the same share, so the energy in the battery
  # has the average price of the window. Without the states of charge at the
  # start and the end of the window, or without the energy of a percent, the
  # share is 1.
  def driven_share(car, window, charged_wh)
    kwh_per_percent = ledger.kwh_per_percent(car)
    soc_start = ledger.daily_soc(car, window.begin - 1)
    soc_end = ledger.daily_soc(car, window.end)
    return 1.0 unless kwh_per_percent && soc_start && soc_end

    driven_wh = charged_wh - ((soc_end - soc_start) * kwh_per_percent * 1000)
    driven_wh.positive? ? driven_wh / charged_wh : 1.0
  end

  # The days that a window of the car can hold: from the first date of the
  # installation to today, inside the period of use of the car. So the rate
  # of a new car holds no energy of the car before it.
  def bounds(car)
    (@bounds ||= {})[car.id] ||= [min_date, car.active_from].compact.max..[Date.current, car.active_until].compact.min
  end

  def window(car, date, margin)
    [date - margin, bounds(car).begin].max..[date + margin, bounds(car).end].min
  end

  # The sum of a daily value of a car over a range of the ledger (see
  # Car::Driving::Sums)
  def sum(car, range, key)
    sums = (@sums ||= {})[car.id] ||= Sums.new(ledger, car)
    sums.call(key, range)
  end
end
