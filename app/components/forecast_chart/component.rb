class ForecastChart::Component < ViewComponent::Base
  attr_reader :timeframe

  REFRESH_INTERVAL = 5.minutes
  private_constant :REFRESH_INTERVAL

  def initialize(timeframe:)
    super()
    @timeframe = timeframe
  end

  def refresh_options
    {
      controller: 'forecast-chart--component',
      'forecast-chart--component-interval-value': REFRESH_INTERVAL,
    }
  end

  def chart_path
    forecast_path
  end

  def frame_id(name)
    "forecast-#{name}"
  end
end
