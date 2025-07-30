class ConsumeDetails::Component < ViewComponent::Base
  def initialize(calculator:)
    super()
    @calculator = calculator
  end

  attr_accessor :calculator
end
