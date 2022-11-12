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

    sections
      .each_with_index
      .sum do |_section, index|
        -(grid_power_plus_array[index] * electricity_price[index] / 1000.0)
      end
      .round(2)
  end

  def got
    return unless grid_power_minus

    sections
      .each_with_index
      .sum do |_section, index|
        (grid_power_minus_array[index] * feed_in_tariff[index] / 1000.0)
      end
      .round(2)
  end

  def solar_price
    return unless got && paid

    got + paid
  end

  def traditional_price
    return unless consumption

    sections
      .each_with_index
      .sum do |_section, index|
        -(consumption_array[index] * electricity_price[index] / 1000.0)
      end
      .round(2)
  end

  def profit
    return unless solar_price && traditional_price

    solar_price - traditional_price
  end

  def battery_profit
    return unless bat_power_minus && bat_power_plus

    sections
      .each_with_index
      .sum do |_section, index|
        (
          (bat_power_minus_array[index] * electricity_price[index] / 1000.0) -
            (bat_power_plus_array[index] * feed_in_tariff[index] / 1000.0)
        )
      end
      .round(2)
  end

  def battery_profit_percent
    return unless profit && battery_profit
    return if profit.zero?

    100.0 * battery_profit / profit
  end
end
