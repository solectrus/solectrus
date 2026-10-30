# The page of the comparison with a combustion car (see Car::Comparison). It
# shows the savings first, then the cost of the three columns as bars, then
# the calculation of each column (see Car::ComparisonColumns::Component).
# Below, a chart shows the periods of the timeframe (see
# Car::ComparisonChart), and another the energy cost of each week per 100 km
# (see Car::ComparisonRateChart). The page has no headings to save height,
# and each section explains itself in an info tooltip beside its title.
#
# Without a car with a combustion car, without fuel prices, or without a
# distance to compare, the page says why there is no comparison.
class Car::ComparisonPage::Component < ViewComponent::Base
  include Car::ComparisonFormat

  # A column of the comparison: its key, its title and its total cost
  Column = Data.define(:key, :title, :total)
  public_constant :Column

  # The cookie of the details. Without it, the page hides them.
  COOKIE = :car_comparison_details
  public_constant :COOKIE

  def self.expanded?(cookies) = cookies[COOKIE] == 'true'

  # `car` is the parameter of the selected car, nil for "all", which each
  # link to the car page keeps. `expanded` shows the details of the
  # calculation (see .expanded?).
  def initialize(report:, car:, expanded: false)
    super()
    @report = report
    @car = car
    @expanded = expanded
  end

  attr_reader :report

  def expanded? = @expanded

  delegate :comparison, :timeframe, to: :report

  # What the data of the comparison lacks, as warnings above the figures
  def gaps = Car::ComparisonGaps.new(report).to_a

  # The amounts as the page shows them, so each column adds up
  def amounts = @amounts ||= Car::ComparisonAmounts.new(comparison)

  # The calculation of each column
  def calculation = Car::ComparisonColumns::Component.new(report:, car: @car, columns:, amounts:)

  # The chart of the periods. The chart of the weeks below shares its bar
  # groups, so a week stands under the bars of its period.
  def chart = @chart ||= Car::ComparisonChart::Component.new(report:, car: @car, titles: columns.map(&:title))

  # :no_prices without fuel prices, :none without a combustion car,
  # :no_distance without a day with a cost and a fuel price. The prices come
  # first, so the page does not ask for settings that give no comparison.
  # The car page shows the savings when the comparison is ready, too (see
  # Car::DrivingBox::Component).
  def state
    return :no_prices unless prices?
    return :none unless comparison
    return :no_distance unless comparison.ready?

    :ready
  end

  # Without a combustion car, the prices of any fuel
  def prices? = comparison ? comparison.possible? : Car::FuelPrices.any?

  # The label of a figure, small and in capitals like the figures of the
  # amortization
  FIGURE_LABEL = 'uppercase tracking-wide font-semibold text-slate-500 dark:text-slate-400'.freeze
  public_constant :FIGURE_LABEL

  # [[label, value, color], ...]: the figures beside the bars. The savings
  # are green for a gain and red for a loss.
  def figures
    per_100km = amounts.savings_per_100km
    [
      [t('.figures.savings'), money(amounts.savings), savings_color_of(amounts.savings)],
      [t('.figures.savings_without_pv'), money(amounts.savings_without_pv), savings_color_of(amounts.savings_without_pv)],
      [t('.figures.savings_per_100km'), money(per_100km, precision: 2), (savings_color_of(per_100km) if per_100km)],
    ]
  end

  # A figure smaller than the savings: its label and its value
  def small_figure(label, value, color)
    helpers.tag.div do
      helpers.safe_join(
        [
          helpers.tag.div(label, class: "#{FIGURE_LABEL} text-[11px] md:text-xs"),
          helpers.tag.div(value, class: "mt-0.5 text-lg md:text-xl font-semibold tabular-nums #{color}"),
        ],
      )
    end
  end

  # The fuel of the combustion car is a setting of the car, so the page
  # speaks of a combustion car alone
  def columns
    @columns ||= [
      Column.new(key: :car, title: t('.columns.car'), total: amounts.car_cost),
      Column.new(key: :without_pv, title: t('.columns.without_pv'), total: amounts.car_cost_without_pv),
      Column.new(key: :combustion, title: t('.combustion').upcase_first, total: amounts.combustion_cost),
    ]
  end

  # The width of the bar of a column, in percent of the highest cost. A
  # negative cost has no bar.
  def bar_width(column)
    highest = columns.map(&:total).max
    return 0 unless highest.positive? && column.total.positive?

    (column.total * 100 / highest).round(1)
  end

  def bar_color(column) = COLORS[column.key]

  # The info tooltip of the figures: how the savings come about, and the
  # data they need as a list. What the data lacks stands above the figures
  # (see Car::ComparisonWarnings::Component).
  def savings_notes = [t('.notes.savings'), t('.notes.data')]

  def settings_link? = helpers.admin?
end
