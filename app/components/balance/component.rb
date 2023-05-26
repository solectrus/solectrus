class Balance::Component < ViewComponent::Base
  renders_one :center

  def initialize(calculator:, timeframe:, peak: nil)
    super
    @calculator = calculator
    @timeframe = timeframe
    @peak = peak
  end

  attr_reader :calculator, :timeframe, :peak
end
