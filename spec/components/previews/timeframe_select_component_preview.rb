# @label TimeframeSelect
# @logical_path navigation
class TimeframeSelectComponentPreview < ViewComponent::Preview
  # @param base_url
  def default(base_url: '/inverter_power')
    timeframe = Timeframe.new('2024-01')

    render TimeframeSelect::Component.new(timeframe:, base_url:)
  end
end
