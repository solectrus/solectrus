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
          - amortized: the operating cash flow has earned back the net
            investment (degree_percent >= 100).
          - degree_percent: operating cash flow / net investment, uncapped, only
            flows up to today. A subsidy lowers the net investment but does not
            inflate this figure.
          - break_even_date: first day the nominal balance reaches zero, null if
            not within the period.
          - installation_date: start of the payback period.
          - net_position: nominal balance today, excluding future-dated flows.
          - gross_investment: all investment outflows up to today, as a magnitude.
          - investment_reduction: subsidies and refunds lowering the base.
          - net_investment: gross_investment - investment_reduction, i.e. what
            actually has to be earned back.
          - operating_cashflow: measured savings plus manual operating flows
            (compensation, manual_savings, operating_cost, repair); excludes
            subsidies/refunds. manual_savings covers periods without measured
            data, e.g. before SOLECTRUS was installed.
          - profit_nominal: nominal surplus at the end of the period, no interest.
          - npv: net present value at the calculatory rate; positive beats an
            alternative investment yielding that rate.
          - irr_percent: internal rate of return, the rate where the NPV is zero.
          - required_annual_savings: annual benefit needed for a non-negative NPV.
          - savings_per_day / savings_per_year: the projection's savings rate
            (rolling year, or all-time average below a year of data);
            per_year = per_day * 365.
          - projection_uncertain: less than a year of measured data.
          - yearly_series: the nominal balance and the amortization degree per
            PV year. PV years run from installation anniversary to anniversary,
            NOT along the calendar: the entry labelled year 2029 is the balance
            on the 2029 anniversary of installation_date, not on 31 December —
            so break_even_date falls between the last negative entry and the
            first positive one, and reporting an entry as "end of <year>" is
            wrong by the months between the anniversary and New Year. The first
            entry is the operating start itself, carrying the investment dip.
            `projected` marks a year that is not yet measured.

        Money is in the system currency (get_system_info) with 2 decimals, dates
        are ISO 8601, rates and degrees are percent with 1 decimal.
        period_years and interest_rate echo the values actually used, clamped
        into range.
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
          degree_percent: percent(result.degree_percent),
          break_even_date: result.break_even_date&.iso8601,
          installation_date: result.installation_date&.iso8601,
          net_position: money(result.net_position),
          **investment_figures(result),
          profit_nominal: money(result.profit_nominal),
          npv: money(result.npv),
          irr_percent: percent(result.irr_percent),
          required_annual_savings: money(result.required_annual_savings),
          savings_per_day: money(result.savings_per_day),
          savings_per_year: money(result.savings_per_year),
          projection_uncertain: result.projection_uncertain,
          yearly_series:
            result.yearly_series.map do |entry|
              entry.merge(nominal: money(entry[:nominal]), degree: percent(entry[:degree]))
            end,
        }
      end
      private_class_method :figures

      def self.investment_figures(result)
        {
          gross_investment: money(result.gross_investment),
          investment_reduction: money(result.investment_reduction),
          net_investment: money(result.net_investment),
          operating_cashflow: money(result.operating_cashflow),
        }
      end
      private_class_method :investment_figures

      def self.money(value)
        Precision.round(value, :money)
      end
      private_class_method :money

      def self.percent(value)
        Precision.round(value, :percent)
      end
      private_class_method :percent

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
