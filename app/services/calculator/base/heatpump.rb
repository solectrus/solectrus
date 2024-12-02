module Calculator::Base::Heatpump
  extend ActiveSupport::Concern

  included do
    def heatpump_heating?
      heatpump_heating_power&.positive?
    end

    def heatpump_power_percent
      return unless heatpump_power && total_minus
      return 0 if total_minus.zero?

      (heatpump_power * 100.0 / total_minus).round(1)
    end

    def heatpump_heating_env
      return unless heatpump_heating_power && heatpump_power

      heatpump_heating_power - heatpump_power
    end

    def heatpump_heating_env_percent
      return unless heatpump_heating_power&.positive? && heatpump_power

      (heatpump_heating_power - heatpump_power) * 100 / heatpump_heating_power
    end

    def heatpump_heating_power_percent
      return unless heatpump_power && heatpump_heating_power&.positive?

      heatpump_power * 100 / heatpump_heating_power
    end

    def heatpump_power_grid_percent
      unless heatpump_power_grid_ratio && heatpump_power &&
               heatpump_heating_power&.positive?
        return
      end

      heatpump_power_grid_ratio * (heatpump_power / heatpump_heating_power)
    end

    def heatpump_power_pv_percent
      unless heatpump_power_pv_ratio && heatpump_power &&
               heatpump_heating_power&.positive?
        return
      end

      heatpump_power_pv_ratio * (heatpump_power / heatpump_heating_power)
    end

    def heatpump_cop
      unless heatpump_power && heatpump_heating_power && heatpump_power.nonzero?
        return
      end

      heatpump_heating_power.fdiv(heatpump_power)
    end
  end
end
