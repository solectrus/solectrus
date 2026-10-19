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
#
# A window reaches into the months around a day, so the days of a month do
# not hold the balance of the month. A past calendar month therefore scales
# its days to its balance: the charged energy less the energy that the
# battery holds more at the end of the month than at the end of the month
# before, and the cost less the value of this energy (see #month_factors).
# So a month and a year count the state of charge at their own ends, and
# the days still add up to them. Without the state of charge, the past
# months of a year scale together to their charged energy and their
# charging cost (see #year_factors).
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

  # A factor of a month outside these bounds hints at missing data, like a
  # charge that a collector did not report. The month then keeps its days.
  FACTORS = 0.5..2.0
  private_constant :FACTORS

  NO_FACTORS = [1.0, 1.0].freeze
  private_constant :NO_FACTORS

  # The dates that the driving of the given dates reads: the windows of
  # their calendar years, for the factors of their months (see
  # #month_factors)
  def self.reach(dates, min_date:) = window_reach(dates.begin.beginning_of_year..dates.end.end_of_year, min_date:)

  # The dates that the windows of the given dates read, enough for #rate:
  # MAX_MARGIN_DAYS more on each side, from the first date of the
  # installation to today. The day before the first window gives the state
  # of charge at its start.
  def self.window_reach(dates, min_date:)
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
    Rate.new(energy_wh: charged_wh * share, cost: (sum(car, window, :cost) * share if costed?(car, window)))
  end

  # The driving of a car on a date, scaled to the balance of its month
  def day(car, date)
    day = window_day(car, date)
    return unless day

    energy, cost = month_factors(car, date.beginning_of_month)
    day.with(energy_wh: day.energy_wh * energy, cost: day.cost * cost)
  end

  # The driving of a car on a date at the rates of its window, or nil without
  # a rate. The balance of the month asks for each of its days, so each day is
  # computed once.
  def window_day(car, date)
    memo(:window_day, car.id, date) do
      distance = ledger.daily_distance(car, date)
      rate = rate(car, date) if distance.positive?
      next unless rate

      cost_distance = rate.cost ? distance : 0.0
      Totals.new(distance:, energy_wh: distance * rate.energy_wh, cost_distance:, cost: cost_distance * rate.cost.to_f)
    end
  end

  # The share of the charged energy of the window that the car drove on: the
  # charged energy less the energy that the battery holds more at the end of
  # the window. The cost takes the same share, so the energy in the battery
  # has the average price of the window. Without the states of charge at the
  # start and the end of the window, or without the energy of a percent, the
  # share is 1.
  def driven_share(car, window, charged_wh)
    wh_per_percent, soc_start, soc_end = battery_ends(car, window)
    return 1.0 unless wh_per_percent

    driven_wh = charged_wh - ((soc_end - soc_start) * wh_per_percent)
    driven_wh.positive? ? driven_wh / charged_wh : 1.0
  end

  # [energy, cost]: the factors that scale the days of a calendar month. A
  # past month inside the bounds of the car scales to its balance with the
  # state of charge at both ends (see #balance_factors), and without it
  # together with the other such months of its year (see #year_factors).
  # Otherwise both factors are 1.
  def month_factors(car, month)
    memo(:month_factors, car.id, month) do
      dates = month.all_month
      next NO_FACTORS unless anchored?(car, dates)

      ends = battery_ends(car, dates)
      ends ? balance_factors(car, dates, ends) : year_factors(car, month.year)[month]
    end
  end

  # Whether a calendar month is past and inside the bounds of the car, with
  # the day before it for the state of charge at its start
  def anchored?(car, dates) = dates.end < Date.current && bounds(car).cover?((dates.begin - 1)..dates.end)

  # The factors to the balance of a month: the charged energy and its cost
  # less the energy that the battery holds more at the end of the month than
  # at the end of the month before, and its value
  def balance_factors(car, dates, ends)
    wh_per_percent, soc_start, soc_end = ends
    energy_wh = sum(car, dates, :energy_wh) - ((soc_end - soc_start) * wh_per_percent)
    cost = balance_cost(car, dates, *ends)
    window = month_window(car, dates)
    [
      (factor(energy_wh, window.energy_wh) if rated?(car, dates, :distance)),
      (factor(cost, window.cost) if cost && rated?(car, dates, :cost_distance)),
    ].map { it || 1.0 }
  end

  # { month => [energy, cost] } of the past months of a year without the
  # state of charge at their ends. Together they scale to their charged
  # energy and their charging cost, because the change of the battery is
  # unknown. Over many charges, this change is a small error. A month that
  # does not hold each kilometer stays out of the energy, and a month with a
  # session without a cost stays out of the cost. The current year takes
  # its past months, so its factors change at the end of each month.
  def year_factors(car, year)
    memo(:year_factors, car.id, year) do
      months = (1..12).map { Date.new(year, it).all_month }.select { anchored?(car, it) && !battery_ends(car, it) }
      energy = group_factors(car, months.select { rated?(car, it, :distance) }, :energy_wh)
      cost = group_factors(car, months.select { rated?(car, it, :cost_distance) && costed?(car, it) }, :cost)
      months.to_h { [it.begin, [energy.fetch(it.begin, 1.0), cost.fetch(it.begin, 1.0)]] }
    end
  end

  # { month => factor }: one factor that scales the windows of the months
  # together to their charged energy or charging cost (`key`), empty
  # outside FACTORS
  def group_factors(car, months, key)
    value = factor(months.sum { sum(car, it, key) }, months.sum { month_window(car, it).public_send(key) })
    value ? months.to_h { [it.begin, value] } : {}
  end

  def factor(balance, window)
    value = balance / window if window.positive?
    value if value && FACTORS.cover?(value)
  end

  # The days of a month at the rates of their windows
  def month_window(car, dates)
    memo(:month_window, car.id, dates.begin) { Totals.sum(dates.filter_map { window_day(car, it) }) }
  end

  # Whether the days of a month hold each of its kilometers, in their
  # distance or in their cost distance
  def rated?(car, dates, member) = month_window(car, dates).public_send(member) >= sum(car, dates, :distance) - 0.5

  # [Wh of a percent, state of charge at the day before the dates, at their
  # last day], nil without one of them. A percent is k of the energy (see
  # ChargingSession.kwh_per_percent).
  def battery_ends(car, dates)
    ends = [ledger.kwh_per_percent(car)&.*(1000), ledger.daily_soc(car, dates.begin - 1), ledger.daily_soc(car, dates.end)]
    ends if ends.all?
  end

  # The cost of the month less the value of the energy in the battery: the
  # energy at each end has the price of the window there (see #price). Nil
  # with a session without a cost or without a price at an end.
  def balance_cost(car, dates, wh_per_percent, soc_start, soc_end)
    start_price, end_price = [dates.begin - 1, dates.end].map { price(car, it) }
    return unless start_price && end_price && costed?(car, dates)

    sum(car, dates, :cost) - (wh_per_percent * ((soc_end * end_price) - (soc_start * start_price)))
  end

  # The price of a Wh in the window of a date, nil without a cost rate. The
  # share of the state of charge cancels out.
  def price(car, date) = rate(car, date)&.then { it.cost / it.energy_wh if it.cost }

  # The days that a window of the car can hold: from the first date of the
  # installation to today, inside the period of use of the car. So the rate
  # of a new car holds no energy of the car before it.
  def bounds(car)
    (@bounds ||= {})[car.id] ||= [min_date, car.active_from].compact.max..[Date.current, car.active_until].compact.min
  end

  def window(car, date, margin)
    [date - margin, bounds(car).begin].max..[date + margin, bounds(car).end].min
  end

  # Whether each session of a car on the dates has a cost
  def costed?(car, dates) = sum(car, dates, :uncosted).zero?

  # The sum of a daily value of a car over a range of the ledger (see
  # Car::Driving::Sums)
  def sum(car, range, key)
    sums = (@sums ||= {})[car.id] ||= Sums.new(ledger, car)
    sums.call(key, range)
  end

  # The days, the months and the years ask for the same values more than
  # once, so each is computed once per key. A nil is kept, too.
  def memo(*key)
    @memo ||= {}
    return @memo[key] if @memo.key?(key)

    @memo[key] = yield
  end
end
