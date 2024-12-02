module Calculator::Base::Custom
  extend ActiveSupport::Concern

  included do
    def custom_power_total
      (1..10).sum { |index| custom_power(index) || 0 }
    end

    def custom_excluded_from_house_power_total
      SensorConfig.x.custom_excluded_from_house_power.sum do |sensor|
        public_send(sensor) || 0
      end
    end

    def custom_power(index)
      public_send(format('custom_%02d_power', index))
    end

    (1..10).each do |index|
      sensor = format('custom_%02d_power', index).to_sym
      define_method(:"#{sensor}_percent") do
        total =
          if sensor.in?(SensorConfig.x.custom_excluded_from_house_power)
            total_minus
          else
            [house_power, custom_power_total].max
          end
        return 0 if total.zero?

        (custom_power(index) || 0) * 100 / total
      end
    end

    def house_power_without_custom
      [house_power - custom_power_total, 0].max
    end

    def house_power_without_custom_percent
      return 0 if house_power.zero?

      house_power_without_custom * 100 / house_power
    end

    def house_power_valid?
      house_power && house_power >= custom_power_total.to_f
    end
  end
end
