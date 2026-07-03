# Area chart of the balance at the end of each year, from the start of the
# simulation to the end of the total period. Negative values = not yet
# amortized. Measured past and projected future are visually distinguished.
class AmortizationChart::Component < ViewComponent::Base
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
      todayYear: Date.current.year,
      todayYearProgress: today_year_progress,
    }
  end

  def currency_code
    Currency.code
  end

  private

  def today_year_progress
    today = Date.current
    days_in_year = today.end_of_year.yday

    (today.yday - 1).fdiv(days_in_year)
  end

  def rounded_series(key)
    result.yearly_series.map { |entry| entry[key].round(2) }
  end

  # Amortization degree per year in whole percent (nil before the first debit).
  def degree_series
    result.yearly_series.map { |entry| entry[:degree]&.round }
  end
end
