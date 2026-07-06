class AmortizationCalculator
  Result =
    Data.define(
      # Operating amortization degree in percent (operating cash flow / net
      # investment * 100), uncapped, flows up to today. Not derived from the
      # nominal balance, so a subsidy/refund lowers the base without inflating
      # the figure. nil without a net investment or any measured data.
      :degree_percent,
      # Nominal amortization: first day the plain cumulative balance reaches
      # zero (interpolated within the month), without interest. nil if the
      # balance never reaches zero within the period.
      :break_even_date,
      # Effective installation date used as the start of the operating
      # payback period.
      :installation_date,
      # Nominal balance as of today, excluding future-dated flows.
      :net_position,
      # Gross investment: magnitude of all investment outflows up to today.
      :gross_investment,
      # Investment reduction: subsidies and refunds that lower the base.
      :investment_reduction,
      # Net investment that actually has to be earned back
      # (gross_investment - investment_reduction).
      :net_investment,
      # Operating cash flow up to today: measured savings plus manual operating
      # flows (compensation, operating_cost, repair); excludes subsidies/refunds.
      :operating_cashflow,
      # Nominal surplus at the end of the total period, without interest.
      :profit_nominal,
      # Net present value: discounted balance at the end of the period
      # (residual value 0). Positive = beats an investment yielding the
      # calculatory rate.
      :npv,
      # Internal rate of return in % p.a. - the rate at which the NPV is
      # exactly zero. nil if there is no zero crossing.
      :irr_percent,
      # Annual benefit required for a non-negative NPV at the given rate.
      # nil without a net investment.
      :required_annual_savings,
      # Measured average savings per day since installation.
      :savings_per_day,
      # Savings of the rolling year (or extrapolated average if less data).
      :savings_per_year,
      # true if less than a full year of measured data is available.
      :projection_uncertain,
      # Balances for the chart: an anchor at the operating start followed by
      # one point per PV-year birthday (12 months from installation).
      # [{ year:, nominal:, projected:, degree: }]
      :yearly_series,
      # The two parameters the result was computed with, echoed so the view
      # (sliders, tooltips) and the MCP response reflect the values actually
      # used: the operating period in whole years and the calculatory interest
      # rate in % p.a.
      :period_years,
      :interest_rate,
    ) do
      def amortized?
        degree_percent.present? && degree_percent >= 100
      end

      def prognosis?
        degree_percent.present?
      end

      # Total operating time from installation to the nominal break-even, in
      # decimal years. nil until break-even is known (never reached within the
      # period). From the actual day difference - month arithmetic would round
      # 8.73 up to 8.8.
      def total_years
        return unless break_even_date && installation_date

        years = (break_even_date - installation_date).to_f / 365.25
        years.negative? ? nil : years
      end
    end
  public_constant :Result
end
