class Calculator::Range < Calculator::Base
  def initialize(timeframe, timestamp)
    super()
    raise ArgumentError unless timeframe.to_s.in?(%w[day week month year all])

    build_context PowerSum
                    .new(
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
                      ],
                    )
                    .public_send(timeframe, timestamp)
  end

  def forecast_quality
    return if watt.zero?

    (100 * inverter_power / watt) - 100
  end

  def paid
    return unless grid_power_plus

    -(grid_power_plus * electricity_price / 1000.0).round(2)
  end

  def got
    return unless grid_power_minus

    (grid_power_minus * feed_in_tariff / 1000.0).round(2)
  end

  def solar_price
    return unless got && paid

    got + paid
  end

  def traditional_price
    return unless consumption

    -(consumption * electricity_price / 1000.0).round(2)
  end

  def profit
    return unless solar_price && traditional_price

    solar_price - traditional_price
  end

  def battery_profit
    return unless bat_power_minus && bat_power_plus

    (
      (bat_power_minus * electricity_price / 1000.0) -
        (bat_power_plus * feed_in_tariff / 1000.0)
    ).round(2)
  end

  def battery_profit_percent
    return unless profit && battery_profit
    return if profit.zero?

    100.0 * battery_profit / profit
  end

  def electricity_price
    Rails.configuration.x.electricity_price
  end

  def feed_in_tariff
    Rails.configuration.x.feed_in_tariff
  end
end
