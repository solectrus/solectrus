class Calculator
  RATE         = 0.2545
  COMPENSATION = 0.0832

  def initialize(timeframe)
    raise ArgumentError unless timeframe.in?([:last24h])

    @inverter_power   = TimeSeries.new('inverter_power').send(timeframe)
    @house_power      = TimeSeries.new('house_power').send(timeframe)
    @grid_power_plus  = TimeSeries.new('grid_power_plus').send(timeframe)
    @grid_power_minus = TimeSeries.new('grid_power_minus').send(timeframe)
  end

  attr_reader :inverter_power, :house_power, :grid_power_plus, :grid_power_minus

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
end
