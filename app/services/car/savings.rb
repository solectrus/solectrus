# The savings of the cars of a report against their combustion cars, as the
# car page shows them below the card of the driving (see
# Car::PeriodOverview::Driving::Savings and Car::ComparisonAmounts). Each
# render of the cards shows them, and the comparison of a long timeframe
# rates each day twice, with and without the PV system. So the amounts stay
# in the cache until one of their inputs changes: the summaries around the
# dates, the charging sessions, the cars, the prices, the payments or the
# fuel prices. The page of the comparison calculates them anew each time.
class Car::Savings
  # The amounts of the car page, each rounded to `precision`
  Amounts = Data.define(:precision, :car_cost, :combustion_cost) do
    def savings = combustion_cost - car_cost
  end
  public_constant :Amounts

  def initialize(report)
    @report = report
  end

  # The amounts, nil without a compared distance (see Car::Comparison#ready?)
  def amounts
    values = Rails.cache.fetch(cache_key, expires_in: 1.day) { compute }
    Amounts.new(**values) if values
  end

  private

  attr_reader :report

  # The cache holds numbers only, so an entry of an older version of the app
  # reads without the classes of this one
  def compute
    comparison = report.comparison
    return unless comparison.ready?

    amounts = Car::ComparisonAmounts.new(comparison)
    { precision: amounts.precision, car_cost: amounts.car_cost.to_f, combustion_cost: amounts.combustion_cost.to_f }
  end

  # The rate of a day comes from the days around it and from the factors of
  # its month and year (see Car::Driving.reach), so the summaries count over
  # that reach. The rates of the charged energy come from all sessions of
  # the cars. Today is part of the key, because a relative timeframe like
  # the current week covers other days tomorrow.
  def cache_key
    dates = report.dates
    cars = report.cars
    reach = Car::Report.reach(report.timeframe)

    [
      'car_savings',
      Date.current,
      dates.begin,
      dates.end,
      cars.map(&:id),
      report.guest?,
      Car.where(id: cars).cache_key_with_version,
      Summary.where(date: reach).cache_key_with_version,
      ChargingSession.all.cache_key_with_version,
      Price.all.cache_key_with_version,
      Car::Payment.all.cache_key_with_version,
      *cars.map(&:fuel_type).uniq.sort.map { Car::FuelPrices.new(it).cache_version },
    ]
  end
end
