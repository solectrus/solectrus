class AmortizationCalculator
  # Splits the cash flows booked up to today into the figures that drive the
  # amortization degree: the (net) investment base and the operating cash flow.
  # Kept separate from the nominal balance so a subsidy/refund lowers the base
  # instead of being counted as operating payback.
  class Categorization
    def initialize(cash_flows:, savings:, today:)
      @cash_flows = cash_flows
      @savings = savings
      @today = today
    end

    attr_reader :cash_flows, :savings, :today

    # Gross investment: magnitude of all investment outflows.
    def gross_investment
      -sum_of('investment')
    end

    # Investment reduction: subsidies and refunds that lower the base.
    def investment_reduction
      sum_of('subsidy', 'refund')
    end

    # Net investment that actually has to be earned back.
    def net_investment
      gross_investment - investment_reduction
    end

    # Operating cash flow: measured savings plus manual operating flows
    # (compensation adds, operating_cost/repair subtract). Subsidies/refunds are
    # deliberately excluded - they lower the base, they are not operating payback.
    def operating_cashflow
      savings.total_measured.to_f + operating_flows
    end

    # Operating amortization degree in percent: how much of the net investment
    # the operating cash flow has earned back so far. nil without a net
    # investment or any measured data.
    def degree_percent
      return unless net_investment.positive?
      return unless savings.total_measured || operating_flows.nonzero?

      operating_cashflow.fdiv(net_investment) * 100
    end

    private

    def operating_flows
      sum_of(*CashFlow::OPERATING_CATEGORIES)
    end

    # Cash flows booked up to today - the classified figures reflect the current
    # state, so future-dated entries are excluded, just like the nominal ledger.
    def past_flows
      @past_flows ||= cash_flows.select { |date, _amount, _category| date <= today }
    end

    # Signed sum of the past flows in the given categories.
    def sum_of(*categories)
      past_flows.sum do |_date, amount, category|
        categories.include?(category) ? amount : 0.0
      end
    end
  end
end
