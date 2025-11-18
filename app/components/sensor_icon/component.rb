class SensorIcon::Component < ViewComponent::Base
  def initialize(sensor, data: nil, **options)
    super()
    @sensor = sensor
    @data = data
    @options = options
  end

  attr_reader :sensor, :data, :options

  def call
    return unless icon_class_name

    tag.i(class: icon_class, style: icon_style)
  end

  private

  def icon_class
    ['fa', icon_class_name, options[:class]]
  end

  def icon_style
    options[:style]
  end

  def icon_class_name
    sensor.icon(data:)
  end
end
