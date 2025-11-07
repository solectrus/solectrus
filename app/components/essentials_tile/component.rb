class EssentialsTile::Component < ViewComponent::Base
  def initialize(data:, sensor:, timeframe:)
    super()
    @data = data
    @sensor = sensor
    @timeframe = timeframe
  end

  attr_reader :data, :sensor, :timeframe

  def path
    balance_home_path(
      sensor_name: sensor.name,
      timeframe: timeframe.original_string,
    )
  end

  def value
    @value ||= data.public_send(sensor.name)
  end

  def background_color
    return 'bg-gray-600 dark:bg-gray-700' if value.nil? || value.round.zero?

    sensor.color_bg
  end

  def title
    case sensor.name
    when :co2_reduction
      t(
        'sensors.co2_reduction_note',
        co2_emission_factor: Rails.configuration.x.co2_emission_factor,
      )
    else
      sensor.display_name
    end
  end

  def formatted_value
    return '---' unless value

    context =
      if sensor.name == :inverter_power
        timeframe.now? ? :rate : :total
      else
        :auto
      end
    unit = sensor.unit

    result = Sensor::ValueFormatter.new(value, unit:, context:).to_h

    safe_join(
      [
        result[:integer],
        (tag.small(result[:decimal]) if result[:decimal].present?),
        '&nbsp;'.html_safe,
        tag.small(result[:unit]),
      ].compact,
    )
  end

  def refresh_interval
    [
      interval_by_timeframe,
      Rails.configuration.x.influx.poll_interval.seconds,
    ].max
  end

  def interval_by_timeframe
    if timeframe.now?
      5.seconds
    elsif timeframe.day?
      1.minute
    elsif timeframe.week?
      5.minutes
    elsif timeframe.month?
      10.minutes
    elsif timeframe.year?
      1.hour
    else
      1.day
    end
  end
end
