# @label Balance
class BalanceComponentPreview < ViewComponent::Preview
  def default
    render Balance::Component.new timeframe:, calculator:, sensor:
  end

  private

  def calculator
    Calculator::Range.new(timeframe)
  end

  def timeframe
    Timeframe.new Date.current.strftime('%Y-%m')
  end

  def sensor
    'inverter_power'
  end
end
