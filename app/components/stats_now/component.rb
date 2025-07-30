class StatsNow::Component < ViewComponent::Base
  def initialize(calculator:, sensor:)
    super()
    @calculator = calculator
    @sensor = sensor
  end

  attr_accessor :calculator, :sensor

  def max_flow
    #  Heuristic: The peak flow rate is the highest value
    #  of all fields.
    #
    # If we have no data (e.g. right after installation or
    # resetting the summaries), we assume an estimated value of 5 KW
    @max_flow ||= peak ? peak.values.compact.max : 5000
  end

  def timeframe
    Timeframe.now
  end

  def peak
    @peak ||=
      PowerPeak.new(sensors: SensorConfig::POWER_SENSORS).call(
        start: 30.days.ago,
      )
  end
end
