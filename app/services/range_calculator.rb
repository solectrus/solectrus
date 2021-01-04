class RangeCalculator < BaseCalculator
  RATE         = 0.2545
  COMPENSATION = 0.0832

  def initialize(timeframe)
    super()
    raise ArgumentError unless timeframe.to_s.in?(%w[day week month year all])

    build_context FluxQuery.new(
      :inverter_power,
      :house_power,
      :grid_power_plus,
      :grid_power_minus,
      :bat_power_minus,
      :bat_power_plus
    ).public_send(timeframe)
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
    return unless house_power

    -(house_power * RATE / 1000.0).round(2)
  end

  def profit
    return unless solar_price && traditional_price

    solar_price - traditional_price
  end
end
