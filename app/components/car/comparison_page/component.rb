# The page of the comparison with a combustion car (see Car::Comparison). It
# compares the car with the combustion car, and a button adds the car
# without the PV system as a third column. It shows the savings first, then
# the cost of the columns as bars, then the calculation of each column (see
# Car::ComparisonColumns::Component). Below, a chart shows the periods of the
# timeframe (see Car::ComparisonChart), and another the energy cost of each
# week per 100 km (see Car::ComparisonRateChart), only below the chart of
# the periods. So a short timeframe has no charts. The page has no headings
# to save height, and each section explains itself in an info tooltip
# beside its title.
#
# Without a car with a combustion car, without fuel prices, or without a
# distance to compare, the page says why there is no comparison.
class Car::ComparisonPage::Component < ViewComponent::Base
  include Car::ComparisonFormat

  # A column of the comparison: its key, its title and its total cost. The
  # suffix follows the title beside the car without PV.
  Column = Data.define(:key, :title, :total, :suffix) do
    def initialize(key:, title:, total:, suffix: nil) = super
  end
  public_constant :Column

  # The cookie of the details. Without it, the page hides them.
  COOKIE = :car_comparison_details
  public_constant :COOKIE

  # The cookie of the column without PV. Without it, the page hides the
  # column.
  WITHOUT_PV_COOKIE = :car_comparison_without_pv
  public_constant :WITHOUT_PV_COOKIE

  # The motion of the head when the car without PV comes or goes. Its parts
  # keep their place, so the head does not move: they fade (see
  # Car::ComparisonFormat::WITHOUT_PV_FADE). On a desktop,
  # the bar of the combustion car moves up into the place of the bar of the
  # car without PV, which has the same height. A phone opens and closes that
  # bar instead, without a gap.
  WITHOUT_PV_OPEN = "grid transition-[grid-template-rows] #{MOTION} max-lg:grid-rows-[0fr] max-lg:group-data-without-pv/comparison:grid-rows-[1fr]".freeze
  WITHOUT_PV_SHIFT = "transition-transform #{MOTION} lg:-translate-y-full lg:group-data-without-pv/comparison:translate-y-0".freeze
  private_constant :WITHOUT_PV_OPEN, :WITHOUT_PV_SHIFT

  def self.expanded?(cookies) = cookies[COOKIE] == 'true'
  def self.without_pv?(cookies) = cookies[WITHOUT_PV_COOKIE] == 'true'

  # `car` is the parameter of the selected car, nil for "all", which each
  # link to the car page keeps. `expanded` shows the details of the
  # calculation (see .expanded?), `without_pv` the column without PV (see
  # .without_pv?).
  def initialize(report:, car:, expanded: false, without_pv: false)
    super()
    @report = report
    @car = car
    @expanded = expanded
    @without_pv = without_pv
  end

  attr_reader :report

  def expanded? = @expanded
  def without_pv? = @without_pv

  delegate :comparison, :timeframe, to: :report

  # What the data of the comparison lacks, as warnings above the figures
  def gaps = Car::ComparisonGaps.new(report).to_a

  # The amounts as the page shows them, so each column adds up
  def amounts = @amounts ||= Car::ComparisonAmounts.new(comparison)

  # The calculation of each column
  def calculation = Car::ComparisonColumns::Component.new(report:, car: @car, columns:, amounts:)

  # The chart of the periods. The chart of the weeks below shares its bar
  # groups, so a week stands under the bars of its period.
  def chart = @chart ||= Car::ComparisonChart::Component.new(report:, car: @car, columns:)

  def rate_chart = Car::ComparisonRateChart::Component.new(comparison:, columns:, axis: chart.axis)

  # The chart of the weeks shows only below the chart of the periods
  def charts? = chart.render?

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

  # The label of a figure
  FIGURE_LABEL = 'font-semibold text-slate-500 dark:text-slate-400'.freeze
  public_constant :FIGURE_LABEL

  # The buttons below the columns: the details of the calculation, and the
  # car without PV
  PILL_BUTTON = 'inline-flex items-center gap-2 cursor-pointer rounded-full border border-slate-300 dark:border-slate-600 px-4 py-1.5 text-sm font-medium text-slate-600 dark:text-slate-300 hover:bg-slate-100 dark:hover:bg-slate-800 transition-colors focus-ring'.freeze
  public_constant :PILL_BUTTON

  # [[label, value, color], ...]: the figures beside the bars. The savings
  # are green for a gain and red for a loss.
  def figures
    per_100km = amounts.savings_per_100km
    [
      [t('.figures.savings'), money(amounts.savings, precision: amounts.precision), savings_color_of(amounts.savings)],
      [t('.figures.savings_without_pv'), money(amounts.savings_without_pv, precision: amounts.precision), savings_color_of(amounts.savings_without_pv)],
      [t('.figures.savings_per_100km'), money(per_100km, precision: 2), (savings_color_of(per_100km) if per_100km)],
    ]
  end

  # A figure smaller than the savings: its label and its value
  def small_figure(label, value, color)
    helpers.tag.div do
      helpers.safe_join(
        [
          helpers.tag.div(label, class: "#{FIGURE_LABEL} text-xs md:text-sm"),
          helpers.tag.div(value, class: "mt-0.5 text-lg md:text-xl font-semibold tabular-nums #{color}"),
        ],
      )
    end
  end

  # The fuel of the combustion car is a setting of the car, so the page
  # speaks of a combustion car alone. The car without PV is the column that
  # the button adds, so its title names it.
  def columns
    @columns ||= [
      Column.new(key: :car, title: t('.ev'), total: amounts.car_cost, suffix: t('.with_pv')),
      Column.new(key: :without_pv, title: t('.ev_without_pv'), total: amounts.car_cost_without_pv),
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

  # The title and the cost of a column above its bar
  def bar(column)
    tag = helpers.tag
    head = tag.div(class: 'flex items-baseline justify-between gap-3 text-sm md:text-base') do
      tag.span(column_title(column)) + tag.span(money(column.total, precision: amounts.precision), class: 'font-semibold tabular-nums')
    end
    track = tag.div(class: 'mt-1 h-3 rounded-full bg-slate-200 dark:bg-slate-700') do
      tag.div(class: "h-3 rounded-full #{COLORS[column.key]}", style: "width: #{bar_width(column)}%")
    end
    head + track
  end

  # The info tooltip of the figures: how the savings come about, and the
  # data they need as a list. What the data lacks stands above the figures
  # (see Car::ComparisonWarnings::Component).
  def savings_notes = [t('.notes.savings'), t('.notes.data')]

  def settings_link? = helpers.admin?
end
