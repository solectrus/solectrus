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
      # Coerce a raw (possibly nil, string or tampered) value to the default and
      # clamp it into the allowed range.
      def clamp_period(value)
        (value || DEFAULT_PERIOD_YEARS).to_i.clamp(PERIOD_RANGE)
      end

      # Round to the slider's 0.1 step before clamping. Without quantization the
      # rate stays a continuous float that flows verbatim into the
      # content-addressed cache key, so a public visitor could sweep fractional
      # values to bypass the cache (a full recompute every request) and flood
      # the store with entries.
      def clamp_interest(value)
        (value || DEFAULT_INTEREST_RATE).to_f.round(1).clamp(INTEREST_RANGE)
      end
    end
  end
end
