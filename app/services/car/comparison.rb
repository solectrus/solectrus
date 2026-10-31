# The cost of the cars against a combustion car that drives the same
# distance (docs/cars.md, #2407). Each car compares with its own combustion
# car: its fuel, its consumption (l/100 km) and its yearly tax.
#
# The comparison has three columns:
#
# - The car: its driving cost (see Car::Driving).
# - The car without the PV system: the same, but the grid gives all the
#   energy of the wallbox.
# - The combustion car: the fuel for the distance at the price of each day
#   (see Car::FuelPrices), and its tax.
#
# A day counts only with a cost of the car in both columns and with a fuel
# price, so the three columns drive the same distance. The tax counts for
# each day in the period of use of the car, because a tax is due for the
# time and not for the distance. The payments of the car change its cost:
# the GHG quota lowers it, its vehicle tax, the fees of its charging tariffs
# and its running costs, like the insurance and the maintenance, raise it.
# The running costs count for the combustion car too, at the same amount
# (see Car::Payment). So they show the sizes of the costs, but change no
# saving. A payment spreads evenly over the days of its year in the period
# of use, like the tax, because these payments are due for a year.
class Car::Comparison # rubocop:disable Metrics/ClassLength
  # The sources of the energy are no part of the totals, because the weeks
  # of the chart of the rates do not need them (see #energy_sources)
  Totals =
    Data.define(:distance, :liters, :fuel_cost, :tax, :cost, :cost_without_pv, :energy_wh) do
      def self.sum(list) = new(**members.index_with { |member| list.sum(&member) })
    end
  private_constant :Totals

  # A compared payment (see Car::Payment), spread over its span: its
  # category, its amount as a cost (an income negative), and its span with
  # the number of its days (see #payment_span). The periods of a
  # timeframe share the payments, so each span is known once.
  PaymentSpread = Data.define(:category, :cost, :span, :days)
  private_constant :PaymentSpread

  # A day of a car with a cost in both columns and a fuel price: its
  # driving, its driving without PV (see Car::Driving) and the fuel price
  ComparedDay = Data.define(:date, :driving, :without_pv, :price)
  private_constant :ComparedDay

  # The comparison takes each timeframe of whole days, so the timeframe
  # select offers all kinds but the last hours (see
  # Timeframe::Select::Component::KINDS). The live view has no comparison
  # either.
  TIMEFRAME_KINDS = %i[day week month year range days months all].freeze
  public_constant :TIMEFRAME_KINDS

  def self.timeframe?(timeframe) = !(timeframe.now? || timeframe.hours?)

  # The comparison needs the fuel prices, which a collector writes. Without
  # them, the comparison and its settings stay out of sight.
  def self.available? = Car::FuelPrices.any?

  # The timeframe of the comparison: a timeframe of the comparison (see
  # .timeframe?) as it is, the live view and the last hours as today
  def self.timeframe(timeframe) = timeframe?(timeframe) ? timeframe : Timeframe.of(timeframe.effective_ending_date, :day)

  # The comparisons of the periods of a timeframe share the drivings, the
  # fuel prices, the payments and the compared days (see #for)
  def initialize(cars, dates, driving:, driving_without_pv:, fuel_prices: {}, payments: nil, days: nil) # rubocop:disable Metrics/ParameterLists
    @cars = cars
    @dates = dates
    @driving = driving
    @driving_without_pv = driving_without_pv
    @fuel_prices = fuel_prices
    @all_payments = payments
    @all_days = days
  end

  attr_reader :cars, :dates

  # The comparison of a part of the dates, for example a year of the whole
  # time
  def for(dates)
    self.class.new(cars, dates, driving:, driving_without_pv:, fuel_prices: @fuel_prices, payments: all_payments, days: all_days)
  end

  # [[whole period, comparison], ...] of the years, the months or the weeks
  # (`by`) of the dates. The first and the last comparison hold only their
  # part of the dates.
  def split(by)
    starts =
      case by
      when :year then (dates.begin.year..dates.end.year).map { Date.new(it) }
      when :month then Enumerator.produce(dates.begin.beginning_of_month, &:next_month).take_while { it <= dates.end }
      when :week then (dates.begin.beginning_of_week..dates.end).step(7).to_a
      end
    periods = starts.map { |start| start..start.public_send(:"end_of_#{by}") }
    periods.map { [it, self.for(clamp(it))] }
  end

  # Whether InfluxDB holds the prices of the fuel of each car. Without them,
  # there is no comparison and no fallback.
  def possible?
    cars.all? { fuel_prices(it).any? }
  end

  # Whether the comparison has savings to show: fuel prices and a distance
  # to compare
  def ready? = possible? && distance.positive?

  delegate :distance, :liters, :fuel_cost, :tax, :cost, :cost_without_pv, :energy_wh, to: :totals

  # The payments are the cost of the compared payments of the cars, an income
  # negative. The shared cost is their part that the combustion car has too.
  # They do not depend on the days of the cars, so a period without a need
  # for them, like a week of the chart of the rates, does not compute them.
  def payments = payment_costs.values.sum
  def shared_cost = payment_costs.slice(*Car::Payment::SHARED).values.sum

  # { category => cost } of the compared payments, a category without a
  # payment in the dates left out. They add up to the payments.
  def payment_costs
    @payment_costs ||= Car::Payment::COMPARED.filter_map do |category|
      cost = payment_cost(category)
      [category, cost] if cost.nonzero?
    end.to_h
  end

  # { source => Car::EnergySources::Source } of the car, with and without
  # the PV system: the energy and the cost by the source of the charged
  # energy, a source without energy left out. They add up to the energy and
  # the cost.
  def sources = energy_sources.present
  def sources_without_pv = energy_sources.without_pv(cost_without_pv).present

  # The total cost of each column
  def combustion_cost = fuel_cost + tax + shared_cost
  def car_cost = cost + payments
  def car_cost_without_pv = cost_without_pv + payments

  # A value of the distance per 100 km, nil without a distance, for example
  # the running costs of a column. The difference of the running costs per
  # 100 km is the savings per 100 km (see Car::ComparisonAmounts). The
  # comparison holds only a part of the costs of a car, without its
  # purchase, so it gives differences and no ratios.
  def per_100km(value)
    (value * 100).fdiv(distance) if distance.positive?
  end

  # The consumption of the combustion car (l/100 km), an average of the cars
  def consumption = per_100km(liters)

  # [[date, price], [date, price]]: the lowest and the highest fuel price on
  # the dates, each with the date of its week, nil without a price. The page
  # and the modal of the prices (see Car::FuelPriceChart::Component) show
  # the same two prices.
  def fuel_price_extremes
    prices = fuel_series.values.flatten(1)
    prices.minmax_by(&:last) if prices.any?
  end

  # The range of the lowest and the highest fuel price, nil without a price.
  # Each day has its own price, so the page shows their range and no
  # average.
  def fuel_price_range
    fuel_price_extremes&.then { |(_, lowest), (_, highest)| lowest..highest }
  end

  # Whether the distance holds each kilometer of the cars on the dates. A day
  # without a cost or a fuel price stays out, and then the car page shows a
  # longer distance.
  def whole_distance? = same_distance?(cars.sum { driving.distance(it, dates) })

  # Whether the distance is the one of the driving cost, so the car page
  # shows the same driving cost and the same cost per 100 km
  def driving_distance? = same_distance?(driving_totals.cost_distance)

  # Whether the distance is the one of the consumption, so the car page
  # shows the same consumption per 100 km. A day with an energy rate but
  # without a cost rate counts there, but not here.
  def consumption_distance? = same_distance?(driving_totals.distance)

  # The filter of the list of the payments that the payments come from: the
  # compared categories of the car, or some of them, in the years of the
  # dates. A part of a year has a part of its payments, and the list shows
  # them in full.
  def payment_filter(categories = Car::Payment::COMPARED)
    Car::PaymentFilter.new(
      car: (cars.sole if cars.one?),
      categories:,
      from: dates.begin.beginning_of_year,
      to: dates.end.end_of_year,
    )
  end

  # { fuel type => [[date, price], ...] } of the cars on the dates, for a
  # stepped line (see Car::FuelPrices#series)
  def fuel_series
    @fuel_series ||= cars.map(&:fuel_type).uniq.index_with { prices_of(it).series(dates) }
  end

  # The yearly tax of the combustion car, nil for several cars
  def yearly_tax = (cars.sole.combustion_tax.to_f if cars.one?)

  private

  attr_reader :driving, :driving_without_pv

  def totals
    @totals ||= Totals.sum(cars.map { car_totals(it) })
  end

  def driving_totals
    @driving_totals ||= driving.totals(dates, cars:)
  end

  def same_distance?(other) = (other - distance).abs < 0.5

  def car_totals(car)
    days = compared_days(car)
    liters = days.map { it.driving.cost_distance * car.fuel_consumption.to_f / 100 }
    Totals.new(
      distance: days.sum { it.driving.cost_distance },
      liters: liters.sum,
      fuel_cost: days.zip(liters).sum { |day, day_liters| day_liters * day.price },
      tax: yearly_tax_share(car),
      cost: days.sum { it.driving.cost },
      cost_without_pv: days.sum { it.without_pv.cost },
      energy_wh: days.sum { it.driving.energy_wh },
    )
  end

  # The sources of the driven energy of the compared days of the cars. Each
  # compared day has a cost rate, so it has its sources.
  def energy_sources
    @energy_sources ||= cars.sum(Car::EnergySources.empty) { |car| compared_days(car).sum(Car::EnergySources.empty) { driving.sources(car, it.date) } }
  end

  # The compared days of a car on the dates (see ComparedDay)
  def compared_days(car)
    (@compared_days ||= {})[car.id] ||= dates.filter_map { all_days[car.id][it] }
  end

  # { car id => { date => compared day } } of the dates, computed once for
  # their periods
  def all_days = @all_days ||= cars.to_h { [it.id, days_of(it).index_by(&:date)] }

  def days_of(car)
    without_pv = driving_without_pv.days(car, dates).to_h
    driving.days(car, dates).filter_map do |date, day|
      other = without_pv[date]
      price = fuel_prices(car).at(date) if day.cost_rated? && other&.cost_rated?
      ComparedDay.new(date:, driving: day, without_pv: other, price:) if price
    end
  end

  # The tax of each day in the period of use, a 365th or a 366th of the
  # yearly tax. So a whole year has the yearly tax. The tax counts before
  # the first distance too, like the payments.
  def yearly_tax_share(car)
    yearly = car.combustion_tax.to_f
    days = driving.in_use(car, dates)
    return 0.0 unless yearly.positive? && days

    days.sum { yearly / (Date.gregorian_leap?(it.year) ? 366 : 365) }
  end

  # The payments of the cars of a category in the dates as a cost: the
  # expenses less the incomes. Each payment gives the dates the part of its
  # span that they hold up to today. So the current year has only a part of
  # its payments.
  def payment_cost(category)
    dates_until_today = dates.begin..[dates.end, Date.current].min
    all_payments.select { it.category == category }.sum do |payment|
      payment.cost * days_in(payment.span, dates_until_today) / payment.days
    end.to_f
  end

  # The days of the year of a payment in the period of use of the car. A
  # payment outside the period of use counts on its date alone.
  def payment_span(car, date)
    from = [date.beginning_of_year, car.active_from].compact.max
    to = [date.end_of_year, car.active_until].compact.min
    from <= to ? from..to : date..date
  end

  # The number of days that two ranges of dates share
  def days_in(range, other)
    from = [range.begin, other.begin].max
    to = [range.end, other.end].min
    from <= to ? (to - from).to_i + 1 : 0
  end

  # The compared payments of the cars in the years of the dates, loaded once
  # for the periods of the dates, each with its span (see PaymentSpread)
  def all_payments
    @all_payments ||= Car::Payment.compared.where(car_id: cars.map(&:id), date: dates.begin.beginning_of_year..dates.end.end_of_year).map do |payment|
      span = payment_span(cars.find { it.id == payment.car_id }, payment.date)
      PaymentSpread.new(category: payment.category, cost: -payment.signed_amount, span:, days: (span.end - span.begin).to_i + 1)
    end
  end

  def clamp(range) = [range.begin, dates.begin].max..[range.end, dates.end].min

  def fuel_prices(car) = prices_of(car.fuel_type)

  def prices_of(fuel_type)
    @fuel_prices[fuel_type] ||= Car::FuelPrices.new(fuel_type)
  end
end
