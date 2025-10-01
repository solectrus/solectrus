class AutarkyDetails::Component < ViewComponent::Base
  def initialize(calculator:)
    super()
    @calculator = calculator
  end

  attr_accessor :calculator

  def number_method
    @number_method ||=
      calculator.is_a?(Calculator::Now) ? :to_watt : :to_watt_hour
  end
end
