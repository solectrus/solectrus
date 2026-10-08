class StatsWithChart::Component < ViewComponent::Base
  def initialize(sensor_name:, timeframe:)
    super()
    @sensor_name = sensor_name
    @timeframe = timeframe
  end

  attr_reader :sensor_name, :timeframe

  # The year comparison puts twelve months next to each other, once per year.
  # That needs the whole width, so the stats step aside for it.
  delegate :year_comparison?, to: :helpers

  def refresh_options
    {
      controller: 'stats-with-chart--component',
      'stats-with-chart--component-sensor-name-value': sensor_name,
      'stats-with-chart--component-interval-value':
        (
          if timeframe.past?
            0
          elsif timeframe.now?
            Influx::PollInterval.current
          else
            5.minutes
          end
        ),
      'stats-with-chart--component-reload-chart-value': !timeframe.now?,
    }
  end

  # Only the chart knows the comparison, so `compare` stays out of the path of
  # the stats. Left in, it would land as a query parameter on a route that has
  # no segment for it.
  def stats_path
    frame_path('stats', except: [:compare])
  end

  def charts_path
    frame_path('charts')
  end

  private

  def frame_path(kind, except: [])
    params = helpers.permitted_params.to_hash.symbolize_keys.except(*except)

    helpers.url_for(
      params.merge(
        controller: "#{helpers.controller_namespace}/#{kind}",
        **helpers.selection_params,
      ),
    )
  end
end
