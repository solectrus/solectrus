class TimeframeSelectComponentPreview < ViewComponent::Preview
  def default(sensor_name: 'inverter_power', controller_namespace: 'balance')
    timeframe = Timeframe.new('2024-01')

    render TimeframeSelect::Component.new(
             timeframe:,
             sensor_name:,
             controller_namespace:,
           )
  end
end
