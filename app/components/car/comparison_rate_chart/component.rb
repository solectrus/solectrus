# The weeks of the comparison with a combustion car as a chart (see
# Car::ComparisonPage::Component): a line for the electricity cost of the
# car, of the car without PV and the fuel cost of the combustion car, each
# per 100 km, in the colors of their columns. Like the bar in the chart of
# the periods, the line without PV shows only with the button of the page.
# A week counts its energy alone. The tax and the payments spread over the
# days, so a week with a short distance would jump. A week without a
# distance has no point. With fewer than two weeks, there is no chart.
class Car::ComparisonRateChart::Component < ViewComponent::Base
  include Car::ComparisonFormat

  # The energy cost of each column
  COSTS = { car: :cost, without_pv: :cost_without_pv, combustion: :fuel_cost }.freeze
  private_constant :COSTS

  # `columns` are the columns of the page in the order of the lines, so the
  # tooltip names them the same. `axis` gives the bar groups of the chart of
  # the periods above, nil without that chart (see
  # Car::ComparisonChart::Component#axis).
  def initialize(comparison:, columns:, axis: nil)
    super()
    @comparison = comparison
    @columns = columns
    @axis = axis
  end

  def render? = weeks.many?

  # The color classes of the lines
  def colors = column_colors(@columns)

  # The data of the chart: a point gives the cost of a week per 100 km. With
  # the bar groups above, the axis takes their labels, and each week has its
  # position on it.
  def chart_data
    {
      weeks: weeks.map { { from: it.dates.begin.iso8601, to: it.dates.end.iso8601, distance: Sensor::ValueFormatter.new(it.distance.round, unit: :kilometer).to_s } },
      labels: @axis&.map(&:first),
      positions: (weeks.map { position(it.dates.begin) } if @axis),
      series: column_series(@columns) { |key| weeks.map { it.per_100km(it.public_send(COSTS[key])).round(2) } },
    }.compact
  end

  private

  # The position of a date on the axis of the bar groups: the index of its
  # group plus its share of the period, so the middle of the third year is
  # about 2.5. Each group has the same width, also a month with fewer days.
  # A date between two groups, in a period without bars, starts the next.
  def position(date)
    index = @axis.index { |_, dates| date <= dates.end } || @axis.size
    dates = @axis[index]&.last
    return index.to_f unless dates&.cover?(date)

    (index + (date - dates.begin).fdiv(dates.end - dates.begin + 1)).round(4)
  end

  # The comparisons of the weeks with a distance. The first and the last
  # week hold only their part of the timeframe.
  def weeks
    @weeks ||= @comparison.split(:week).map(&:last).select { it.distance.positive? }
  end
end
