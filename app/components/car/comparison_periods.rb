# The periods of a chart of a comparison (see Car::ComparisonChart::Component
# and Heatpump::ComparisonChart::Component). The whole time has a bar group
# for each year, a year for each month, a month none. Another timeframe has a
# group for each month up to a year, and for each year beyond. A month, or
# fewer than three periods, has no chart: the figures above say as much.
#
# The component has the `timeframe`, its `periods` and the `chart_dates`
# whose length picks months or years.
module Car::ComparisonPeriods
  MIN_PERIODS = 3
  private_constant :MIN_PERIODS

  def render? = periods.size >= MIN_PERIODS

  # The title names the period of a bar group
  def title = t(".title.#{by}")

  private

  # The kind of the periods, nil for none
  def by
    return @by if defined?(@by)

    @by =
      if timeframe.all? then :year
      elsif timeframe.year? then :month
      elsif !timeframe.month?
        dates = chart_dates
        (dates.end - dates.begin).to_i >= 366 ? :year : :month
      end
  end

  def label(start) = by == :year ? start.year.to_s : l(start, format: '%b')

  # The period in full, for the tooltip
  def period_name(start) = by == :year ? start.year.to_s : l(start, format: '%B %Y')
end
