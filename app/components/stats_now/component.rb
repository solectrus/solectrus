class StatsNow::Component < ViewComponent::Base
  def initialize(calculator:, sensor:)
    super
    @calculator = calculator
    @sensor = sensor
  end

  attr_accessor :calculator, :sensor

  def max_flow
    # Heuristic: The peak flow is the highest value of all fields
    @max_flow ||= peak.values.max
  end

  def timeframe
    Timeframe.now
  end

  def peak
    @peak ||=
      Summary.where(date: 30.days.ago..).calculate_all(
        *SensorConfig::POWER_SENSORS.map { |sensor| :"max_max_#{sensor}" },
      )
  end
end
