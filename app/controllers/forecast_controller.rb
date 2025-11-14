class ForecastController < ApplicationController
  def index
    if turbo_frame_request?
      # Update multiple frames with turbo_stream response
      render formats: :turbo_stream
    else
      # Render HTML page with frame placeholders
      render
    end
  end

  private

  helper_method def title
    t('forecast.title')
  end

  helper_method def timeframe
    @timeframe ||= Timeframe.new("#{Date.current}..#{Date.current + 7.days}")
  end

  helper_method def forecast_days
    @forecast_days ||= Sensor::Chart::Forecast.new(timeframe:).actual_days
  end

  helper_method def nav_items
    %w[now day week month year all].map do |timeframe|
      {
        name: t("data.#{timeframe}"),
        href: balance_home_path(sensor_name: 'inverter_power', timeframe:),
        current: false,
      }
    end
  end
end
