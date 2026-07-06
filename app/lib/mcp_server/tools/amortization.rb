module McpServer
  module Tools
    # Profitability of the PV system: when the investment pays off and the key
    # financial figures behind it. Combines the measured savings (sensor
    # :savings) with the manually kept cash flow register (investments, costs,
    # revenue) - see AmortizationCalculator.
    class Amortization < Base
      tool_name 'get_amortization'
      title 'Get amortization / payback figures'
      description <<~TEXT.strip
        Get the profitability of the PV system: whether and when the investment
        pays off, plus the key financial figures. Combines the measured savings
        with the manually kept cash flow register (investments, costs, revenue).

        Returns:
          - amortized: true once the operating cash flow has earned back the net
            investment (degree_percent >= 100).
          - degree_percent: operating amortization degree (operating cash flow /
            net investment, uncapped, only flows up to today). A subsidy/refund
            lowers the net investment but does not inflate this figure.
          - break_even_date: first day the nominal balance reaches zero (null if
            not within the period).
          - installation_date: start of the payback period.
          - net_position: nominal balance as of today (excludes future-dated flows).
          - gross_investment: magnitude of all investment outflows up to today.
          - investment_reduction: subsidies and refunds that lower the base.
          - net_investment: what actually has to be earned back
            (gross_investment - investment_reduction).
          - operating_cashflow: measured savings plus manual operating flows
            (compensation, operating_cost, repair); excludes subsidies/refunds.
          - profit_nominal: nominal surplus at the end of the period (no interest).
          - npv: net present value at the calculatory rate (positive = beats an
            alternative investment yielding that rate).
          - irr_percent: internal rate of return (rate at which the NPV is zero).
          - required_annual_savings: annual benefit needed for a non-negative NPV.
          - savings_per_day / savings_per_year: average savings rate used for the
            projection (rolling year, or all-time average with less than a year of
            data); savings_per_year = savings_per_day * 365.
          - projection_uncertain: true with less than a year of measured data.
          - yearly_series: nominal balance at each year-end (projected flag per year).

        All money values are in the system currency (see get_system_info); dates
        are ISO 8601, rates and the degree are percent. period_years and
        interest_rate echo the values actually used (clamped into range).

        Parameters (both optional, for what-if scenarios; default to 20 years
        and 3 % p.a.):
          - period_years: total lifetime in years (10-30).
          - interest_rate: calculatory interest rate in % p.a. (0-10).
      TEXT
      input_schema(
        properties: {
          period_years: {
            type: 'integer',
            description: 'Total lifetime in years (10-30). Defaults to 20.',
          },
          interest_rate: {
            type: 'number',
            description: 'Calculatory interest rate in % p.a. (0-10). Defaults to 3.',
          },
        },
      )
      read_only idempotent: true

      def self.call(period_years: nil, interest_rate: nil, **)
        return no_data_response unless CashFlow.exists?

        json_response(**payload(period_years, interest_rate))
      end

      def self.payload(period_years, interest_rate)
        effective_period = AmortizationCalculator.clamp_period(period_years)
        effective_rate = AmortizationCalculator.clamp_interest(interest_rate)

        result =
          AmortizationCalculator.result(
            period_years: effective_period,
            interest_rate: effective_rate,
          )

        {
          currency: Rails.configuration.x.currency,
          period_years: effective_period,
          interest_rate: effective_rate,
          **figures(result),
        }
      end
      private_class_method :payload

      def self.figures(result)
        {
          amortized: result.amortized?,
          degree_percent: round2(result.degree_percent),
          break_even_date: result.break_even_date&.iso8601,
          installation_date: result.installation_date&.iso8601,
          net_position: round2(result.net_position),
          **investment_figures(result),
          profit_nominal: round2(result.profit_nominal),
          npv: round2(result.npv),
          irr_percent: round2(result.irr_percent),
          required_annual_savings: round2(result.required_annual_savings),
          savings_per_day: round2(result.savings_per_day),
          savings_per_year: round2(result.savings_per_year),
          projection_uncertain: result.projection_uncertain,
          yearly_series:
            result.yearly_series.map do |entry|
              entry.merge(nominal: round2(entry[:nominal]))
            end,
        }
      end
      private_class_method :figures

      def self.investment_figures(result)
        {
          gross_investment: round2(result.gross_investment),
          investment_reduction: round2(result.investment_reduction),
          net_investment: round2(result.net_investment),
          operating_cashflow: round2(result.operating_cashflow),
        }
      end
      private_class_method :investment_figures

      def self.round2(value)
        value&.round(2)
      end
      private_class_method :round2

      def self.no_data_response
        json_response(
          available: false,
          message:
            'No cash flows configured yet, so there is nothing to amortize. ' \
              'Add investments/costs/revenue in the settings first.',
        )
      end
      private_class_method :no_data_response
    end
  end
end
