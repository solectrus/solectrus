# @label ConsumptionDetails::Component
class ConsumptionDetailsComponentPreview < ViewComponent::Preview
  def default
    render ConsumptionDetails::Component.new calculator:
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
