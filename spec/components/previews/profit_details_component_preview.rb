# @label ProfitDetails Component
class ProfitDetailsComponentPreview < ViewComponent::Preview
  def default
    render ProfitDetails::Component.new calculator:
  end

  private

  def calculator
    Calculator::Range.new(timeframe)
  end

  def timeframe
    Timeframe.new Date.current.strftime('%Y-%m')
  end
end
