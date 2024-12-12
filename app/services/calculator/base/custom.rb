module Calculator::Base::Custom
  extend ActiveSupport::Concern

  def custom_sensor_name(index)
    format('custom_power_%02d', index).to_sym
  end

  def custom_power_total
    @custom_power_total ||=
      (1..SensorConfig::CUSTOM_SENSOR_COUNT).sum do |index|
        if custom_sensor_name(index).in?(
             SensorConfig.x.custom_excluded_from_house_power,
           )
          0
        else
          custom_power(index) || 0
        end
      end
  end

  def custom_excluded_from_house_power_total
    SensorConfig.x.custom_excluded_from_house_power.sum do |sensor|
      public_send(sensor) || 0
    end
  end

  def custom_power(index)
    public_send custom_sensor_name(index)
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

  included do
    (1..SensorConfig::CUSTOM_SENSOR_COUNT).each do |index|
      sensor_name = format('custom_power_%02d', index).to_sym

      define_method(:"#{sensor_name}_percent") do
        total =
          if sensor_name.in?(SensorConfig.x.custom_excluded_from_house_power)
            total_minus
          else
            [house_power, custom_power_total].max
          end
        return 0 if total.zero?

        (custom_power(index) || 0) * 100 / total
      end
    end
  end
end
