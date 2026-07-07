class AmortizationCalculator
  # Discounting primitive: the factor that discounts an amount `months` after
  # the reference point back to it, at the given rate. Used wherever cash flows
  # or savings are discounted to the operating start.
  module Discounting
    def self.factor(rate, months)
      (rate + 1)**(months / 12.0)
    end
  end
end
