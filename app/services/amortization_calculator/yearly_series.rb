class AmortizationCalculator
  # Builds the per-year points for the amortization chart from the nominal
  # monthly balance series: an anchor at the operating start followed by one
  # point per PV-year birthday, each carrying the nominal balance and the
  # cumulative amortization degree at that month.
  class YearlySeries
    def initialize(nominal:, monthly:, savings:, period_years:, current_month:)
      @nominal = nominal
      @monthly = monthly
      @savings = savings
      @period_years = period_years
      @current_month = current_month
    end

    attr_reader :nominal, :monthly, :savings, :period_years, :current_month

    # Points anchored on the installation date rather than the calendar: a
    # leading anchor at the operating start (carrying the initial investment, so
    # the chart opens at its deepest point) followed by one point per PV-year
    # birthday - the balance after each whole 12-month block counted from the
    # installation month. Every segment thus spans a full year; the first and
    # last year no longer show a shallower slope from a partial calendar year
    # (see #5712). Months after the current one are projected.
    def to_a
      balance_at = nominal.to_h
      installation_month = savings.installation_month
      first_month, first_balance = nominal.first

      entries = [
        entry(year: first_month.year, month: first_month, balance: first_balance),
      ]

      (1..period_years).each do |elapsed|
        month = installation_month + ((elapsed * 12) - 1).months
        entries << entry(
          year: installation_month.year + elapsed,
          month:,
          balance: balance_at[month],
        )
      end

      entries
    end

    private

    def entry(year:, month:, balance:)
      {
        year:,
        nominal: balance,
        projected: month > current_month,
        degree: degree_by_month[month],
      }
    end

    # Cumulative operating amortization degree (operating cash flow / net
    # investment * 100) at the end of each month, as a running series so the
    # chart can show it per year. Matches the headline degree_percent, so a
    # subsidy/refund lowers the base without inflating the curve. nil while no
    # net investment has been booked yet.
    def degree_by_month
      @degree_by_month ||=
        begin
          cum_operating = 0.0
          cum_net_investment = 0.0

          monthly.months.index_with do |month|
            cum_operating += monthly.operating_in(month)
            cum_net_investment += monthly.net_investment_in(month)
            if cum_net_investment.positive?
              cum_operating.fdiv(cum_net_investment) * 100
            end
          end
        end
    end
  end
end
