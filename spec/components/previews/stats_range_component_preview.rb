# @label StatsRange
class StatsRangeComponentPreview < ViewComponent::Preview
  def default
    render StatsRange::Component.new calculator:, timeframe:, field:
  end

  private

  def calculator
    Calculator::Range.new(timeframe)
  end

  def timeframe
    Timeframe.new Date.current.strftime('%Y-%m')
  end

  def field
    'grid_power_plus'
  end
end
