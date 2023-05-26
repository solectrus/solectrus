# @label Balance Component
class BalanceComponentPreview < ViewComponent::Preview
  def default
    render Balance::Component.new timeframe:, calculator:
  end

  private

  def calculator
    Calculator::Range.new(timeframe)
  end

  def timeframe
    Timeframe.new Date.current.strftime('%Y-%m')
  end
end
