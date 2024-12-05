module Calculator::Base::Heatpump
  extend ActiveSupport::Concern

  included do
    def heatpump_power_percent
      return unless heatpump_power && total_minus
      return 0 if total_minus.zero?

      (heatpump_power * 100.0 / total_minus).round(1)
    end
  end
end
