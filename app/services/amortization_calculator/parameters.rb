class AmortizationCalculator
  # The two parameters the calculation takes - operating period and calculatory
  # interest rate - and the values they may have. Every entry point (the slider
  # component, the controller and the MCP tool) coerces user input through the
  # clamps here, so no other place has to know what a valid parameter is.
  module Parameters
    extend ActiveSupport::Concern

    PERIOD_RANGE = 10..30
    public_constant :PERIOD_RANGE

    INTEREST_RANGE = 0.0..10.0
    public_constant :INTEREST_RANGE

    DEFAULT_PERIOD_YEARS = 20
    public_constant :DEFAULT_PERIOD_YEARS

    DEFAULT_INTEREST_RATE = 3.0 # % p. a.
    public_constant :DEFAULT_INTEREST_RATE

    class_methods do
      # The periods this installation can actually be evaluated with:
      # PERIOD_RANGE, raised from below by the system's age. A period that has
      # already ended says nothing about the investment, so the minimum grows
      # with the years the system has been running - one running for 12 years
      # cannot be looked at over 10.
      def period_range
        minimum_operating_years.clamp(PERIOD_RANGE)..PERIOD_RANGE.max
      end

      # Coerce a raw (possibly nil, string or tampered) value to the default and
      # clamp it into the allowed range.
      def clamp_period(value)
        (value || DEFAULT_PERIOD_YEARS).to_i.clamp(period_range)
      end

      # Round to the slider's 0.1 step before clamping. Without quantization the
      # rate stays a continuous float that flows verbatim into the
      # content-addressed cache key, so a public visitor could sweep fractional
      # values to bypass the cache (a full recompute every request) and flood
      # the store with entries.
      def clamp_interest(value)
        (value || DEFAULT_INTEREST_RATE).to_f.round(1).clamp(INTEREST_RANGE)
      end

      private

      # The smallest whole number of years reaching at least today.
      def minimum_operating_years
        date = Rails.configuration.x.installation_date
        years = Date.current.year - date.year
        years += 1 if date + years.years < Date.current
        years
      end
    end
  end
end
