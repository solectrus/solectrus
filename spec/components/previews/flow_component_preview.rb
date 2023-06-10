# @label Flow
class FlowComponentPreview < ViewComponent::Preview
  # @!group Misc

  # @label 1_000
  def value1000
    render Flow::Component.new value: 1000, max: 11_000
  end

  # @label 2_000
  def value2000
    render Flow::Component.new value: 2000, max: 11_000
  end

  # @label 5_000
  def value5000
    render Flow::Component.new value: 5000, max: 11_000
  end

  # @label 10_000
  def value10000
    render Flow::Component.new value: 10_000, max: 11_000
  end

  # @!endgroup
end
