class Calculator
  RATE         = 0.2545
  COMPENSATION = 0.0832

  # TODO: Separate current from last*
  def initialize(timeframe)
    raise ArgumentError unless timeframe.to_s.in?(%w[current last24h last7d last30d])

    result = TimeSeries.new(
      :inverter_power,
      :house_power,
      :grid_power_plus,
      :grid_power_minus,
      :bat_fuel_charge,
      :bat_power_minus,
      :bat_power_plus
    ).public_send(timeframe)

    @inverter_power   = result[:inverter_power]
    @house_power      = result[:house_power]
    @grid_power_plus  = result[:grid_power_plus]
    @grid_power_minus = result[:grid_power_minus]
    @bat_fuel_charge  = result[:bat_fuel_charge]
    @bat_power_minus  = result[:bat_power_minus]
    @bat_power_plus   = result[:bat_power_plus]
    @time             = result[:time]
  end

  attr_reader :inverter_power, :house_power,
              :grid_power_plus, :grid_power_minus,
              :bat_power_plus, :bat_power_minus,
              :bat_fuel_charge,
              :time

  def paid
    -(@grid_power_plus * RATE / 1000.0).round(2)
  end

  def got
    (@grid_power_minus * COMPENSATION / 1000.0).round(2)
  end

  def solar_price
    got + paid
  end

  def traditional_price
    -(house_power * RATE / 1000.0).round(2)
  end

  def profit
    solar_price - traditional_price
  end

  def live?
    time && time > 10.seconds.ago
  end
end
