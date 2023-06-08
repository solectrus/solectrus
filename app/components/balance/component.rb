class Balance::Component < ViewComponent::Base
  renders_one :center

  def initialize(calculator:, timeframe:, field:, peak: nil)
    super
    @calculator = calculator
    @timeframe = timeframe
    @peak = peak
    @field = field
  end

  attr_reader :calculator, :timeframe, :field, :peak
end
