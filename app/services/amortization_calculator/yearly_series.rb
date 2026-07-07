class AmortizationCalculator
  # Builds the per-year points for the amortization chart: a leading anchor at
  # the operating start (from the nominal monthly series, so the chart opens on
  # the investment dip) followed by one point per PV-year birthday taken from
  # the day-accurate yearly_table - so the chart plots exactly the figures the
  # table tabulates, carrying the nominal balance and the amortization degree.
  class YearlySeries
    def initialize(nominal:, monthly:, savings:, current_month:, yearly_table:)
      @nominal = nominal
      @monthly = monthly
      @savings = savings
      @current_month = current_month
      @yearly_table = yearly_table
    end

    attr_reader :nominal, :monthly, :savings, :current_month, :yearly_table

    # Points anchored on the installation date rather than the calendar: a
    # leading anchor at the operating start (carrying the initial investment, so
    # the chart opens at its deepest point) followed by one point per PV-year
    # birthday. The birthday points come straight from the day-accurate
    # yearly_table, so the chart and the table plot the identical figures - the
    # last point equals the table's last row (see #5712 for the full-year
    # anchoring). Months/years after the current one are projected.
    def to_a
      installation_month = savings.installation_month
      first_month, first_balance = nominal.first

      entries = [
        entry(year: first_month.year, month: first_month, balance: first_balance),
      ]

      yearly_table.each_with_index do |row, index|
        entries << {
          year: installation_month.year + index + 1,
          nominal: row[:nominal],
          projected: row[:projected],
          degree: row[:degree],
        }
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
