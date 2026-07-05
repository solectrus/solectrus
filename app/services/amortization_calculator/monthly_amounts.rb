class AmortizationCalculator
  # Builds the monthly amount series over the whole simulation period:
  # measured/projected savings plus the cash flows booked in each month.
  class MonthlyAmounts
    def initialize(savings:, cash_flows:, period_end_date:)
      @savings = savings
      @cash_flows = cash_flows
      @period_end_date = period_end_date
    end

    attr_reader :savings, :cash_flows, :period_end_date

    # Entries dated before installation (e.g. a down payment) must not be
    # swallowed, so the simulation starts at the earlier of the two.
    def start_month
      @start_month ||=
        [
          savings.effective_installation_date,
          cash_flows.first&.first,
        ].compact.min.beginning_of_month
    end

    def months
      @months ||=
        Enumerator
          .produce(start_month, &:next_month)
          .take_while { |month| month <= period_end_date.beginning_of_month }
    end

    def amounts
      @amounts ||=
        months.map { |month| savings.savings_for(month) + flows_in(month).sum(&:last) }
    end

    def flows_in(month)
      flows_by_month.fetch(month, [])
    end

    # Credits booked in the given month: savings plus positive cash flows.
    def credits_in(month)
      savings.savings_for(month) +
        flows_in(month).sum { |_date, amount| amount.positive? ? amount : 0.0 }
    end

    # Debits booked in the given month: the absolute value of negative flows.
    def debits_in(month)
      -flows_in(month).sum { |_date, amount| amount.negative? ? amount : 0.0 }
    end

    # Zero-based index of the given date's month within the series, counted
    # from the simulation start.
    def index_of(date)
      ((date.year * 12) + date.month) - (start_month.year * 12) - start_month.month
    end

    private

    # Bucket cash flows by month once, so the monthly walk stays O(flows)
    # instead of rescanning every cash flow for each of up to 480 months.
    def flows_by_month
      @flows_by_month ||=
        cash_flows.group_by { |date, _amount| date.beginning_of_month }
    end
  end
end
