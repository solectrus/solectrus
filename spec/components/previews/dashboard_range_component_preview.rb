# @label DashboardRange Component
class DashboardRangeComponentPreview < ViewComponent::Preview
  def default
    render DashboardRange::Component.new calculator:, timeframe:
  end

  private

  def calculator
    Calculator::Range.new(timeframe)
  end

  def timeframe
    Timeframe.new Date.current.strftime('%Y-%m')
  end
end
