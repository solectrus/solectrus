# @label TimeframeSelect
# @logical_path navigation
class TimeframeSelectComponentPreview < ViewComponent::Preview
  # @param sensor_name
  def default(sensor_name: 'inverter_power')
    timeframe = Timeframe.new('2024-01')
    page = TimeframePage::Sensor.new(namespace: 'balance', sensor_name:)

    render TimeframeSelect::Component.new(timeframe:, page:)
  end
end
