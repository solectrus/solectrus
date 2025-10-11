class Balance::Component < ViewComponent::Base
  renders_one :center

  def initialize(data:, timeframe:, sensor:, peak: nil)
    super()
    @data = data
    @timeframe = timeframe
    @peak = peak
    @sensor = sensor
  end

  attr_reader :data, :timeframe, :sensor, :peak
end
