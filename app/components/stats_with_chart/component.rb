class StatsWithChart::Component < ViewComponent::Base
  # `min_interval` makes the live view refresh less often than the data
  # arrives, for a page whose values change slowly. `rigid_stats` is for
  # stats that cannot shrink: they keep their height, and the chart below
  # takes the rest, so it does not cover them.
  def initialize(sensor_name:, timeframe:, chart: true, min_interval: nil, rigid_stats: false)
    super()
    @sensor_name = sensor_name
    @timeframe = timeframe
    @chart = chart
    @min_interval = min_interval
    @rigid_stats = rigid_stats
  end

  attr_reader :sensor_name, :timeframe, :min_interval

  # Without a chart, the stats take the whole height
  def chart? = @chart

  # Above the chart, the stats take three fifths of the height. Side by side
  # on a large screen, they take the full height. Rigid stats grow to their
  # content instead of a fixed minimum, which a smaller screen than a large
  # one then does not have.
  def stats_class
    return 'flex-1 min-h-0 flex' unless chart?

    class_names('lg:flex-1 h-3/5 lg:h-auto flex', @rigid_stats ? 'min-h-fit lg:min-h-72' : 'min-h-72')
  end

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
            [Influx::PollInterval.current, min_interval].compact.max
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
