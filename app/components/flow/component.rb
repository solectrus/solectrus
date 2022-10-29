class Flow::Component < ViewComponent::Base
  def initialize(value:, max:)
    super
    @value = value
    @max = max
  end

  attr_reader :value, :max

  def height
    return 0 if value.zero?

    [Scale.new(max:).result(value), 100].min
  end
end
