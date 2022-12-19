class Calculator::Range < Calculator::Base
  def initialize(timeframe)
    super()

    sums =
      PowerSum.new(
        measurements: %w[SENEC Forecast],
        fields: %i[
          inverter_power
          house_power
          wallbox_charge_power
          grid_power_plus
          grid_power_minus
          bat_power_minus
          bat_power_plus
          watt
          feed_in_tariff
          electricity_price
        ],
      ).call(timeframe)

    build_context sums
  end

  def forecast_quality
    return if watt.zero?

    (100 * inverter_power / watt) - 100
  end

  def paid
    return unless grid_power_plus

    -section_sum do |index|
      grid_power_plus_array[index] * electricity_price[index]
    end
  end

  def got
    return unless grid_power_minus

    section_sum do |index|
      grid_power_minus_array[index] * feed_in_tariff[index]
    end
  end

  def solar_price
    return unless got && paid

    got + paid
  end

  def traditional_price
    return unless consumption

    -section_sum { |index| consumption_array[index] * electricity_price[index] }
  end

  def savings
    return unless solar_price && traditional_price

    solar_price - traditional_price
  end

  def battery_savings
    return unless bat_power_minus && bat_power_plus

    section_sum do |index|
      (bat_power_minus_array[index] * electricity_price[index]) -
        (bat_power_plus_array[index] * feed_in_tariff[index])
    end
  end

  def battery_savings_percent
    return unless savings && battery_savings
    return if savings.zero?

    (100.0 * battery_savings / savings).round
  end

  private

  def section_sum(&)
    (
      sections.each_with_index.sum { |_section, index| yield(index) } / 1_000.0
    ).round(2)
  end
end
