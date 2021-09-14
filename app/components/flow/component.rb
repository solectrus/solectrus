# TODO: Better styling
# https://stackoverflow.com/questions/62212412/smooth-infinite-animation-flow-with-css
# https://stackoverflow.com/questions/58660120/create-infinite-loop-with-css-keyframes

class Flow::Component < ViewComponent::Base
  MAXIMUM = 10_000

  def initialize(value:, signal:)
    super
    @value = value.to_f
    @signal = signal
  end

  attr_accessor :value, :signal

  def quote
    [@value.to_f / MAXIMUM, 1].min
  end

  def ease_out_cubic
    ((quote - 1)**3) + 1
  end

  def height
    "#{(100 * ease_out_cubic).round}%"
  end
end
