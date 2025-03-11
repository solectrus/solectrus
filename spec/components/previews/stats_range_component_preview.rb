# @label StatsRange
class StatsRangeComponentPreview < ViewComponent::Preview
  def default
    render StatsRange::Component.new(calculator:, timeframe:, sensor:)
  end

  private

  def calculator
    Calculator::Range.new(timeframe)
  end

  def timeframe
    Timeframe.new Date.current.strftime('%Y-%m')
  end

  def sensor
    :grid_import_power
  end
end
