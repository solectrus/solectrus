# @label AutarkyDetails::Component
class AutarkyDetailsComponentPreview < ViewComponent::Preview
  def default
    render AutarkyDetails::Component.new calculator:
  end

  private

  def calculator
    Calculator::Range.new(period, timestamp)
  end

  def period
    'month'
  end

  def timestamp
    Date.current
  end
end
