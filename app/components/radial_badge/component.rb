class RadialBadge::Component < ViewComponent::Base
  def initialize(sensor_name, data:)
    super()

    @sensor = Sensor::Registry[sensor_name]
    @data = data
    @value = data.public_send(sensor_name)
    @value = @value&.round if percent?
  end
  attr_reader :data, :sensor, :value

  def title
    sensor.display_name(:short)
  end

  def percent?
    sensor.unit == :percent
  end

  def neutral?
    # Neutral if not a percent sensor, no value, or no color defined
    !percent? || value.nil? || sensor_color_border.nil?
  end

  def variant_class
    'percent' if percent? && value
  end

  def border_color
    return 'border-slate-200 dark:border-slate-800' if neutral?

    sensor_color_border
  end

  def background_color
    return 'xl:tall:bg-slate-200 xl:tall:dark:bg-slate-800' if neutral?

    sensor.color_background(value:) || 'xl:tall:bg-slate-200 xl:tall:dark:bg-slate-800'
  end

  def text_color
    return 'text-slate-500 dark:text-slate-400' if neutral?

    sensor.color_text(value:) || 'text-slate-500 dark:text-slate-400'
  end

  def sensor_color_border
    return unless percent?

    @sensor_color_border ||= sensor.color_border(value:)
  end
end
