class StatsWithChart::Component < ViewComponent::Base
  def initialize(field:, timeframe:)
    super
    @field = field
    @timeframe = timeframe
  end
  attr_reader :field, :timeframe

  def refresh_options
    return if timeframe.past?

    {
      controller: 'stats-with-chart--component',
      'stats-with-chart--component-field-value': field,
      'stats-with-chart--component-interval-value':
        (timeframe.now? ? 5.seconds : 5.minutes),
      'stats-with-chart--component-reload-chart-value': !timeframe.now?,
      'stats-with-chart--component-next-path-value': next_path,
      'stats-with-chart--component-boundary-value': boundary,
    }
  end

  def next_path
    return unless forced_next_timeframe

    root_path(field:, timeframe: forced_next_timeframe)
  end

  def boundary
    return unless forced_next_timeframe

    forced_next_timeframe.date.beginning_of_day.iso8601
  end

  def forced_next_timeframe
    @forced_next_timeframe ||= timeframe.next(force: true)
  end

  def stats_path
    helpers.stats_path(helpers.permitted_params.to_hash.symbolize_keys)
  end

  def charts_path
    helpers.charts_path(helpers.permitted_params.to_hash.symbolize_keys)
  end

  def chart_loading_animation?
    # Show loading animation for frame requests only, not for the first request
    request.headers.key?('Turbo-Frame')
  end
end
