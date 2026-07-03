class AmortizationCalculator
  # Discounting math for the monthly amount series: NPV at an arbitrary rate
  # and the internal rate of return derived from it. All amounts are
  # discounted to the simulation start (index 0).
  class Discounting
    def self.factor(rate, months)
      (rate + 1)**(months / 12.0)
    end

    def initialize(amounts:)
      @amounts = amounts
    end

    attr_reader :amounts

    def npv_at(other_rate)
      amounts.each_with_index.sum do |amount, index|
        amount / self.class.factor(other_rate, index)
      end
    end

    # Internal rate of return: the rate at which the NPV is zero, found by
    # bisection. nil when there is no zero crossing in the searched range
    # (e.g. only outflows or only inflows).
    def irr_percent
      low = -0.9
      high = 10.0
      return unless npv_at(low).positive? && npv_at(high).negative?

      40.times do
        mid = (low + high) / 2
        npv_at(mid).positive? ? low = mid : high = mid
      end

      (low + high) / 2 * 100
    end
  end
end
