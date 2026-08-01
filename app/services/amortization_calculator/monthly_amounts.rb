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
        months.map do |month|
          savings.savings_for(month) + flows_in(month).sum { |_date, amount, _category| amount }
        end
    end

    # Plain cumulative balance at the end of each month, no interest:
    # [[month_start, balance], ...]. The running total of #amounts, and the
    # basis of both the break-even date and the balance chart.
    def cumulative
      @cumulative ||=
        begin
          balance = 0.0
          months.each_with_index.map do |month, index|
            [month, balance += amounts[index]]
          end
        end
    end

    def flows_in(month)
      flows_by_month.fetch(month, [])
    end

    # Operating cash flow booked in the given month: measured/projected savings
    # plus the manual operating flows (compensation adds, operating_cost/repair
    # subtract). Subsidies/refunds are excluded - they lower the base, not the
    # operating payback.
    def operating_in(month)
      savings.savings_for(month) +
        sum_in(month, CashFlow::OPERATING_CATEGORIES)
    end

    # Net investment booked in the given month: investment raises the base,
    # subsidy/refund lower it. Their signed sum, negated, is the net figure.
    def net_investment_in(month)
      -sum_in(month, CashFlow::INVESTMENT_BASE_CATEGORIES)
    end

    private

    # Signed sum of the given month's flows that fall into the given categories.
    def sum_in(month, categories)
      flows_in(month).sum do |_date, amount, category|
        categories.include?(category) ? amount : 0.0
      end
    end

    # Bucket cash flows by month once, so the monthly walk stays O(flows)
    # instead of rescanning every cash flow for each of up to 480 months.
    def flows_by_month
      @flows_by_month ||=
        cash_flows.group_by { |date, _amount, _category| date.beginning_of_month }
    end
  end
end
