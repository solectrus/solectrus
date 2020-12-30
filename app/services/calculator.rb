class Calculator
  RATE         = 0.2545
  COMPENSATION = 0.0832

  def initialize(timeframe)
    raise ArgumentError unless timeframe.in?([:last24h, :current])

    result = TimeSeries.new(
      :inverter_power,
      :house_power,
      :grid_power_plus,
      :grid_power_minus
    ).public_send(timeframe)

    @inverter_power   = result[:inverter_power]
    @house_power      = result[:house_power]
    @grid_power_plus  = result[:grid_power_plus]
    @grid_power_minus = result[:grid_power_minus]
    @time             = result[:time]
  end

  attr_reader :inverter_power, :house_power, :grid_power_plus, :grid_power_minus, :time

  def paid
    -(@grid_power_plus * RATE).round(2)
  end

  def got
    (@grid_power_minus * COMPENSATION).round(2)
  end

  def solar_price
    got + paid
  end

  def traditional_price
    -(house_power * RATE).round(2)
  end

  def profit
    solar_price - traditional_price
  end

  def live?
    time > 10.seconds.ago
  end
end
