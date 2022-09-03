class Flow::Component < ViewComponent::Base
  renders_one :top
  renders_one :bottom

  def initialize(value:)
    super
    @value = value
  end

  attr_reader :value

  def height
    value / 35
  end
end
