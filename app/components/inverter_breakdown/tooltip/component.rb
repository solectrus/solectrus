class InverterBreakdown::Tooltip::Component < ViewComponent::Base
  def initialize(sensor:, data:, timeframe:)
    super()
    @sensor = sensor
    @data = data
    @timeframe = timeframe
  end

  attr_reader :sensor, :data, :timeframe

  def call
    tag.div class: 'tooltip-layout' do
      render(TooltipHeader::Component.new(title: sensor.display_name, sensor_name: sensor.name, value: data, total: !timeframe.now?))
    end
  end
end
