# The periods of the comparison of the heat pump with a heating that burns
# oil or gas, as a chart: the years of the whole time, the months of a year,
# the months or years of another timeframe (see
# Heatpump::ComparisonPage::Component and Car::ComparisonPeriods). It shares
# the chart of the comparison of a car with a combustion car (see
# car/comparison_chart/component_controller.ts).
#
# Each period has a bar for the cost of each column: the heat pump, the heat
# pump without PV and the heating, in the colors of the columns. The bar
# without PV shows only with the button of the comparison, which adds its
# column. The tooltip gives the period with its heat and the costs. A period
# with fewer compared days than it has gets hatched bars.
class Heatpump::ComparisonChart::Component < ViewComponent::Base
  include Car::ComparisonFormat
  include Car::ComparisonPeriods

  # The cost of each column (see Heatpump::ComparisonAmounts)
  COSTS = { heatpump: :heatpump_cost, without_pv: :without_pv_cost, heating: :heating_cost }.freeze
  private_constant :COSTS

  # `columns` are the columns of the comparison in the order of the bars
  # (see Heatpump::ComparisonPage::Component#columns), so the tooltip names
  # them the same
  def initialize(comparison:, columns:)
    super()
    @comparison = comparison
    @columns = columns
  end

  attr_reader :comparison, :columns

  delegate :timeframe, to: :comparison

  # [[whole dates, comparison], ...] of the periods (see
  # Heatpump::Comparison#split)
  def periods
    return [] unless by

    @periods ||= comparison.split(by)
  end

  def colors = column_colors(columns)

  # The data of the chart: a bar gives the cost of its column, as the page
  # of the period shows it
  def chart_data
    {
      labels: periods.map { |dates, _| label(dates.begin) },
      titles: periods.map { |dates, period| tooltip_title(dates.begin, period) },
      partial: periods.map { |dates, period| partial?(dates, period) },
      series: column_series(columns) { |key| amounts.map(&COSTS[key]) },
    }
  end

  private

  # The amounts of each period, as the page of the period shows them
  def amounts = @amounts ||= periods.map { |_, period| Heatpump::ComparisonAmounts.new(period) }

  def chart_dates = timeframe.effective_dates

  # Whether the comparison has fewer days in a period than it has: the
  # timeframe, today or the start of the heat pump cuts it. Such a period
  # has hatched bars, so it does not look like a cheap one.
  def partial?(dates, period)
    timeframe.partial_period?(dates.begin, by) || period.days < dates.count
  end

  # The period in full, with its heat
  def tooltip_title(start, period)
    "#{period_name(start)} · #{Sensor::ValueFormatter.new(period.heat_wh, unit: :watt, context: :total)}"
  end
end
