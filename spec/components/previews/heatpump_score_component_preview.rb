# @label HeatpumpScore
class HeatpumpScoreComponentPreview < ViewComponent::Preview
  # @!group
  def one
    render HeatpumpScore::Component.new(1)
  end

  def two
    render HeatpumpScore::Component.new(2)
  end

  def three
    render HeatpumpScore::Component.new(3)
  end

  def four
    render HeatpumpScore::Component.new(4)
  end

  def five
    render HeatpumpScore::Component.new(5)
  end
  # @!endgroup
end
