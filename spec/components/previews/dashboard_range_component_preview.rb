# @label DashboardRange Component
class DashboardRangeComponentPreview < ViewComponent::Preview
  def default
    render DashboardRange::Component.new calculator:, period:, timestamp:
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
