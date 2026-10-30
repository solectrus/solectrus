# The periods of the comparison with a combustion car as a chart: the years
# of the whole time, the months of a year (see Car::ComparisonPage::Component).
# Each period has three bars, the total cost of each column: the car, the car
# without PV and the combustion car, in the colors of the columns. The cards
# above name the columns, so the chart has no legend. The tooltip gives the
# period with its distance and the three costs. A period with fewer days
# has hatched bars. A click on a year or a month opens its own comparison.
# A month, or a single period, has no chart.
class Car::ComparisonChart::Component < ViewComponent::Base
  include Car::ComparisonFormat

  # The columns of the comparison in the order of their bars, each with its
  # total cost
  SERIES = { car: :car_cost, without_pv: :car_cost_without_pv, combustion: :combustion_cost }.freeze
  private_constant :SERIES

  # `car` is the parameter of the selected car, nil for "all". `titles` are
  # the titles of the columns on the page, in the order of the bars, so the
  # tooltip names them the same.
  def initialize(report:, car:, titles:)
    super()
    @report = report
    @car = car
    @titles = titles
  end

  attr_reader :report

  delegate :comparison, :timeframe, to: :report

  def render? = periods.many?

  # [[whole dates, comparison], ...] of the periods (see
  # Car::Comparison#split). A period without a distance, a tax and a payment
  # is left out.
  def periods
    return [] unless by

    @periods ||= comparison.split(by).select { |_, period| period.distance.positive? || period.tax.positive? || period.payments.nonzero? }
  end

  # The bar groups, which the chart of the weeks shares (see
  # Car::ComparisonRateChart::Component): the label and the whole calendar
  # period of each group, nil without a chart
  def axis
    periods.map { |dates, _| [label(dates.begin), dates] } if render?
  end

  # The title names the period of a bar group
  def title = t(".title.#{by}")

  # The color classes of the bars
  def colors = SERIES.keys.map { COLORS[it] }

  # The data of the chart: a bar gives the total cost of its column
  def chart_data
    {
      labels: periods.map { |dates, _| label(dates.begin) },
      titles: periods.map { |dates, period| tooltip_title(dates.begin, period) },
      paths:,
      partial: periods.map { |dates, _| partial?(dates) },
      series: @titles.zip(SERIES.values).map { |label, cost| { label:, values: amounts.map(&cost) } },
    }.compact
  end

  private

  # The amounts of each period, as the page of the period shows them
  def amounts = @amounts ||= periods.map { |_, period| Car::ComparisonAmounts.new(period) }

  # The comparison of each period: a year of the whole time, a month of a
  # year
  def paths
    periods.map { |dates, _| helpers.cars_savings_path(car: @car, timeframe: Timeframe.of(dates.begin, by).to_param) }
  end

  # The whole time has a bar group for each year, a year for each month,
  # another timeframe none
  def by
    if timeframe.all?
      :year
    elsif timeframe.year?
      :month
    end
  end

  # Whether the cars drove on fewer days of a period than it has: the
  # timeframe, today or the period of use of the cars cuts it. Such a period
  # has hatched bars, so it does not look like a cheap one.
  def partial?(dates)
    timeframe.partial_period?(dates.begin, by) || !in_use?(dates)
  end

  # Whether a car was in use on each of the dates: from the first start of
  # use of the cars to their last end
  def in_use?(dates)
    cars = comparison.cars
    from = cars.map(&:active_from).min
    to = cars.map(&:active_until).then { it.all? ? it.max : nil }
    from <= dates.begin && (to.nil? || to >= dates.end)
  end

  def label(start) = by == :year ? start.year.to_s : l(start, format: '%b')

  # The period in full, with its distance
  def tooltip_title(start, period)
    name = by == :year ? start.year.to_s : l(start, format: '%B %Y')
    "#{name} · #{Sensor::ValueFormatter.new(period.distance.round, unit: :kilometer)}"
  end
end
