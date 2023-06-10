# @label SavingsDetails
class SavingsDetailsComponentPreview < ViewComponent::Preview
  def default
    render SavingsDetails::Component.new calculator:
  end

  private

  def calculator
    Calculator::Range.new(timeframe)
  end

  def timeframe
    Timeframe.new Date.current.strftime('%Y-%m')
  end
end
