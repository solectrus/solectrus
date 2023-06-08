# @label Balance
class BalanceComponentPreview < ViewComponent::Preview
  def default
    render Balance::Component.new timeframe:, calculator:, field:
  end

  private

  def calculator
    Calculator::Range.new(timeframe)
  end

  def timeframe
    Timeframe.new Date.current.strftime('%Y-%m')
  end
  def field
    'inverter_power'
  end
end
