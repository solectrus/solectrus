# @label ProfitDetails::Component
class ProfitDetailsComponentPreview < ViewComponent::Preview
  def default
    render ProfitDetails::Component.new calculator:
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
