# Area chart of the balance at the end of each year, from the start of the
# simulation to the end of the total period. Negative values = not yet
# amortized. Measured past and projected future are visually distinguished.
class AmortizationChart::Component < ViewComponent::Base
  # Round icon button, matching the maximize/minimize buttons of the other charts.
  ICON_BUTTON_CLASS =
    'flex items-center justify-center p-2 font-medium focus:outline-none ' \
    'focus:ring-2 focus:ring-gray-700 dark:focus:ring-gray-400 text-sm gap-2 ' \
    'hover:bg-gray-200 dark:hover:bg-gray-700 bg-gray-100 dark:bg-gray-800 ' \
    'rounded-full size-8 border border-gray-300 dark:border-gray-600 cursor-pointer'.freeze
  private_constant :ICON_BUTTON_CLASS

  def initialize(result:)
    super()
    @result = result
  end

  attr_reader :result

  def chart_data
    {
      labels: result.yearly_series.pluck(:year),
      nominal: rounded_series(:nominal),
      degree: degree_series,
      projected: result.yearly_series.pluck(:projected),
      todayYear: today_year,
      todayYearProgress: today_year_progress,
      # Balance as of today (= the "net position" KPI), so the today marker on
      # the chart matches that figure exactly instead of being interpolated.
      todayValue: result.net_position&.round(2),
      # Amortization degree as of today, matching the "amortized so far" KPI.
      todayDegree: today_degree,
    }
  end

  def currency_code
    Currency.code
  end

  # Year span of the chart, shown as the fullscreen subtitle (like the timeframe
  # on the other charts), e.g. "2020 - 2045".
  def period_label
    years = result.yearly_series.pluck(:year)
    return if years.empty?

    first, last = years.minmax
    first == last ? first.to_s : "#{first} – #{last}"
  end

  private

  # Same clamp/round as the AmortizationDegree KPI, so the today tooltip shows
  # the identical percentage as the headline.
  def today_degree
    return unless result.degree_percent

    [result.degree_percent.to_f, 0].max.round
  end

  # The x-axis marks are PV-year birthdays (x = installation year + elapsed
  # years), so "today" is placed by how many PV years have elapsed since
  # installation - not by the calendar year. The controller computes the
  # today vertex as todayYear - 1 + progress, i.e. the previous birthday plus
  # the fraction into the current PV year.
  def today_year
    result.installation_date.year + elapsed_pv_years.floor + 1
  end

  def today_year_progress
    elapsed = elapsed_pv_years
    (elapsed - elapsed.floor).clamp(0.0, 1.0)
  end

  def elapsed_pv_years
    @elapsed_pv_years ||=
      (Date.current - result.installation_date).to_f / 365.25
  end

  def rounded_series(key)
    result.yearly_series.map { |entry| entry[key].round(2) }
  end

  # Amortization degree per year in whole percent (nil before the first debit).
  def degree_series
    result.yearly_series.map { |entry| entry[:degree]&.round }
  end
end
