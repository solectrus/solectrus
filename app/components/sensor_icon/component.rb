class SensorIcon::Component < ViewComponent::Base
  def initialize(sensor, data: nil, **options)
    super()
    @sensor = sensor
    @data = data
    @options = options
  end

  attr_reader :sensor, :data, :options

  def call
    return unless icon_name

    icon(icon_name, class: options[:class], style: options[:style])
  end

  private

  # The name comes from the sensor definition, which carries it for the state
  # the data is in - a battery icon follows the charge, for one.
  def icon_name
    sensor.icon(data:)
  end
end
