class Calculator::Range < Calculator::Base
  RATE         = 0.2545
  COMPENSATION = 0.0832

  def initialize(timeframe, timestamp)
    super()
    raise ArgumentError unless timeframe.to_s.in?(%w[day week month year all])

    build_context PowerSum.new(
      measurements: [ 'SENEC' ],
      fields: [
        :inverter_power,
        :house_power,
        :wallbox_charge_power,
        :grid_power_plus,
        :grid_power_minus,
        :bat_power_minus,
        :bat_power_plus
      ]
    ).public_send(timeframe, timestamp)
  end

  def paid
    return unless grid_power_plus

    -(grid_power_plus * RATE / 1000.0).round(2)
  end

  def got
    return unless grid_power_minus

    (grid_power_minus * COMPENSATION / 1000.0).round(2)
  end

  def solar_price
    return unless got && paid

    got + paid
  end

  def traditional_price
    return unless consumption

    -(consumption * RATE / 1000.0).round(2)
  end

  def profit
    return unless solar_price && traditional_price

    solar_price - traditional_price
  end

  def battery_profit
    return unless bat_power_minus && bat_power_plus

    (bat_power_minus * RATE / 1000.0 - bat_power_plus * COMPENSATION / 1000.0).round(2)
  end

  def battery_profit_percent
    return unless profit && battery_profit
    return if profit.zero?

    100.0 * battery_profit / profit
  end
end
