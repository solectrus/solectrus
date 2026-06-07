class ConsumptionBadge::Component < ViewComponent::Base
  def initialize(data:, timeframe:)
    super()
    @data = data
    @timeframe = timeframe
  end
  attr_reader :data, :timeframe

  # Watt sensors render as power (W) by default; for ranged timeframes we want
  # the accumulated energy (Wh) instead, matching the balance sheet segments.
  def value_context
    timeframe.now? ? :rate : :total
  end

  def show?(sensor_name)
    return false unless Sensor::Config.exists?(sensor_name)

    if sensor_name == :total_consumption
      # Skip the redundant sum when there is no heat pump or wallbox, and treat
      # the empty-period 0 as "nothing to show".
      return Sensor::Config.total_consumption_relevant? &&
               data.total_consumption&.nonzero?
    end

    data.public_send(sensor_name).present?
  end

  # Autarky keeps its value-based signal color (red / orange / green) even in the
  # text box, mirroring the former radial badge.
  def autarky_color_class
    Sensor::Registry[:autarky].color_text(value: data.autarky)
  end

  # Data attributes for a badge link. In the live "now" view each link doubles
  # as a `current` target so the chart can read the latest value/time for its
  # flash dot and rolling x-axis window (see stats_with_chart controller).
  def link_data(sensor_name, tooltip:)
    attrs = {
      turbo_prefetch: 'false',
      action: 'stats-with-chart--component#loadChart',
      stats_with_chart__component_sensor_name_param: sensor_name,
      stats_with_chart__component_chart_url_param:
        helpers.balance_charts_path(sensor_name:, timeframe:),
    }

    if tooltip
      attrs[:controller] = 'tooltip'
      attrs[:tooltip_touch_value] = 'long'
    end

    if timeframe.now?
      attrs[:'stats-with-chart--component-target'] = 'current'
      attrs[:'sensor-name'] = sensor_name
      attrs[:value] = data.public_send(sensor_name)
      attrs[:time] = data.time&.to_i
    end

    attrs
  end
end
