class StatsWithChart::Component < ViewComponent::Base
  def initialize(sensor_name:, timeframe:)
    super()
    @sensor_name = sensor_name
    @timeframe = timeframe
  end

  attr_reader :sensor_name, :timeframe

  def refresh_options
    {
      controller: 'stats-with-chart--component',
      'stats-with-chart--component-sensor-name-value': sensor_name,
      'stats-with-chart--component-interval-value':
        (
          if timeframe.past?
            0
          elsif timeframe.now?
            Rails.configuration.x.influx.poll_interval.seconds
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
end
