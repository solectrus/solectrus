class Balance::Component < ViewComponent::Base
  renders_one :center

  def initialize(calculator:, timeframe:, sensor:, peak: nil)
    super()
    @calculator = calculator
    @timeframe = timeframe
    @peak = peak
    @sensor = sensor
  end

  attr_reader :calculator, :timeframe, :sensor, :peak
end
