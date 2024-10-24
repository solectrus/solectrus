class StatsNow::Component < ViewComponent::Base
  def initialize(calculator:, sensor:)
    super
    @calculator = calculator
    @sensor = sensor
  end

  attr_accessor :calculator, :sensor

  def max_flow
    # Heuristic: The peak flow is the highest value of all fields
    @max_flow ||= peak.values.compact.max
  end

  def timeframe
    Timeframe.now
  end

  def peak
    @peak ||=
      PowerPeak.new(sensors: SensorConfig::POWER_SENSORS).call(
        start: 30.days.ago.beginning_of_day,
      )
  end
end
