class AmortizationCalculator
  Result =
    Data.define(
      # Uncapped nominal ratio (credits / debits * 100) of flows up to
      # today, without interest. nil if there are no debits (yet).
      :degree_percent,
      # Nominal amortization: first day the plain cumulative balance reaches
      # zero (interpolated within the month), without interest. nil if the
      # balance never reaches zero within the period.
      :break_even_date,
      # Effective commissioning date used as the start of the operating
      # payback period.
      :commissioning_date,
      # Nominal balance as of today, excluding future-dated flows.
      :net_position,
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
      # Measured average savings per day since commissioning.
      :savings_per_day,
      # Savings of the rolling year (or extrapolated average if less data).
      :savings_per_year,
      # true if less than a full year of measured data is available.
      :projection_uncertain,
      # Year-end balances for the chart:
      # [{ year:, nominal:, projected: }]
      :yearly_series,
    ) do
      def amortized?
        degree_percent.present? && degree_percent >= 100
      end

      def prognosis?
        degree_percent.present?
      end

      # Total operating time from commissioning to the nominal break-even, in
      # decimal years. nil until break-even is known (never reached within the
      # period). From the actual day difference - month arithmetic would round
      # 8.73 up to 8.8.
      def total_years
        return unless break_even_date && commissioning_date

        years = (break_even_date - commissioning_date).to_f / 365.25
        years.negative? ? nil : years
      end
    end
  public_constant :Result
end
