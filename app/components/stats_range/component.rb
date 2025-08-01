class StatsRange::Component < ViewComponent::Base
  def initialize(calculator:, timeframe:, sensor:)
    super()
    @calculator = calculator
    @timeframe = timeframe
    @sensor = sensor
  end

  attr_accessor :calculator, :timeframe, :sensor
end
