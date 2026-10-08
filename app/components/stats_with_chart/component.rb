class StatsWithChart::Component < ViewComponent::Base
  # `min_interval` makes the live view refresh less often than the data
  # arrives, for a page whose values change slowly
  def initialize(sensor_name:, timeframe:, chart: true, min_interval: nil)
    super()
    @sensor_name = sensor_name
    @timeframe = timeframe
    @chart = chart
    @min_interval = min_interval
  end

  attr_reader :sensor_name, :timeframe, :min_interval

  # Without a chart, the stats take the whole height
  def chart? = @chart

  def refresh_options
    {
      controller: 'stats-with-chart--component',
      'stats-with-chart--component-sensor-name-value': sensor_name,
      'stats-with-chart--component-interval-value':
        (
          if timeframe.past?
            0
          elsif timeframe.now?
            [Influx::PollInterval.current, min_interval].compact.max
          else
            5.minutes
          end
        ),
      'stats-with-chart--component-reload-chart-value': !timeframe.now?,
    }
  end

  def stats_path
    helpers.url_for(
      helpers.permitted_params.to_hash.symbolize_keys.merge(
        controller: "#{helpers.controller_namespace}/stats",
        **helpers.selection_params,
      ),
    )
  end

  def charts_path
    helpers.url_for(
      helpers.permitted_params.to_hash.symbolize_keys.merge(
        controller: "#{helpers.controller_namespace}/charts",
        **helpers.selection_params,
      ),
    )
  end
end
