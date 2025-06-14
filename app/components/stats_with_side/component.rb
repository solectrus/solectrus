class StatsWithSide::Component < ViewComponent::Base
  def initialize(sensor:, timeframe:)
    super
    @sensor = sensor
    @timeframe = timeframe
  end

  attr_reader :sensor, :timeframe

  def refresh_options
    {
      controller: 'stats-with-side--component',
      'stats-with-side--component-sensor-value': sensor,
      'stats-with-side--component-interval-value':
        (
          if timeframe.past?
            0
          elsif timeframe.now?
            Rails.configuration.x.influx.poll_interval.seconds
          else
            5.minutes
          end
        ),
      'stats-with-side--component-reload-chart-value': !timeframe.now?,
      'stats-with-side--component-next-path-value': next_path,
      'stats-with-side--component-boundary-value': boundary,
    }
  end

  def next_path
    return unless forced_next_timeframe

    root_path(sensor:, timeframe: forced_next_timeframe)
  end

  def boundary
    return unless forced_next_timeframe

    forced_next_timeframe.date.beginning_of_day.iso8601
  end

  def forced_next_timeframe
    @forced_next_timeframe ||= timeframe.next(force: true)
  end

  def stats_path
    helpers.url_for(
      helpers.permitted_params.to_hash.symbolize_keys.merge(
        controller: "#{helpers.controller_namespace}/stats",
      ),
    )
  end

  def charts_path
    helpers.url_for(
      helpers.permitted_params.to_hash.symbolize_keys.merge(
        controller: "#{helpers.controller_namespace}/charts",
      ),
    )
  end

  def insights_path
    return unless helpers.controller_namespace == 'balance'
    return if timeframe.short?

    helpers.url_for(
      helpers.permitted_params.to_hash.symbolize_keys.merge(
        controller: "#{helpers.controller_namespace}/insights",
      ),
    )
  end

  def chart_loading_animation?
    # Show loading animation for frame requests only, not for the first request
    return false unless helpers.turbo_frame_request?

    # The response can be slow for short timeframe only,
    # because this results in a line chart and queries InfluxDB
    timeframe.short?
  end
end
