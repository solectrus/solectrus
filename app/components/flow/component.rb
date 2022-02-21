class Flow::Component < ViewComponent::Base
  renders_one :top
  renders_one :bottom

  def initialize(calculator:)
    super
    @calculator = calculator
  end

  attr_reader :calculator

  delegate :total, to: :calculator

  def height
    (total / 35.0).round
  end
end
