class DashboardRange::Component < ViewComponent::Base
  def initialize(calculator:, period:, timestamp:)
    super
    @calculator = calculator
    @period = period
    @timestamp = timestamp
  end

  attr_accessor :calculator, :period, :timestamp
end
