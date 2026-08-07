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
          - amortized / degree_percent: whether the operating cash flow has
            earned the net investment back, and how far it has got. The degree
            is uncapped and counts only flows up to today; a subsidy lowers the
            net investment but does not inflate it.
          - break_even_date: first day the nominal balance reaches zero, null if
            not within the period. installation_date starts that period.
          - net_position: nominal balance today, excluding future-dated flows.
          - gross_investment (all investment outflows up to today, as a
            magnitude), investment_reduction (subsidies and refunds) and their
            difference net_investment — what actually has to be earned back.
          - operating_cashflow: measured savings plus manual operating flows
            (compensation, manual_savings, operating_cost, repair); excludes
            subsidies/refunds. manual_savings covers periods without measured
            data, e.g. before SOLECTRUS was installed.
          - profit_nominal (surplus at the end of the period, no interest), npv
            (positive beats an alternative investment at the calculatory rate),
            irr_percent (the rate where the NPV is zero) and
            required_annual_savings (the annual benefit a non-negative NPV
            needs).
          - savings_per_day / savings_per_year: the projection's savings rate
            (rolling year, or all-time average below a year of data);
            per_year = per_day * 365. projection_uncertain marks less than a
            year of measured data.
          - yearly_series: the nominal balance and the amortization degree per
            PV year. PV years run anniversary to anniversary of
            installation_date, NOT along the calendar: the entry labelled 2029
            is the balance on that anniversary, so reporting it as "end of
            2029" is wrong by the months up to New Year, and break_even_date
            falls between the last negative entry and the first positive one.
            The first entry is the operating start itself, carrying the
            investment dip. `projected` marks a year not yet measured.

        Money is in the system currency (get_system_info) with 2 decimals, dates
        are ISO 8601, rates and degrees are percent with 1 decimal.
        period_years and interest_rate echo the values actually used, clamped
        into range.
      TEXT
      input_schema(
        properties: {
          period_years: {
            type: 'integer',
            minimum: AmortizationCalculator::PERIOD_RANGE.min,
            maximum: AmortizationCalculator::PERIOD_RANGE.max,
            default: AmortizationCalculator::DEFAULT_PERIOD_YEARS,
            description:
              'Total lifetime in years. Raised further where the system is ' \
                'already older; the response echoes what was applied.',
          },
          interest_rate: {
            type: 'number',
            minimum: AmortizationCalculator::INTEREST_RANGE.min,
            maximum: AmortizationCalculator::INTEREST_RANGE.max,
            default: AmortizationCalculator::DEFAULT_INTEREST_RATE,
            description: 'Calculatory interest rate in % p.a.',
          },
        },
      )
      read_only idempotent: true

      def self.perform(period_years: nil, interest_rate: nil, **)
        return no_data_payload unless CashFlow.exists?

        payload(period_years, interest_rate)
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

      def self.no_data_payload
        {
          available: false,
          message:
            'No cash flows configured yet, so there is nothing to amortize. ' \
              'Add investments/costs/revenue in the settings first.',
        }
      end
      private_class_method :no_data_payload
    end
  end
end
