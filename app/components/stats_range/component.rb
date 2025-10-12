class StatsRange::Component < ViewComponent::Base
  def initialize(data:, timeframe:, sensor:)
    super()
    @data = data
    @timeframe = timeframe
    @sensor = sensor
  end

  attr_accessor :data, :timeframe, :sensor
end
