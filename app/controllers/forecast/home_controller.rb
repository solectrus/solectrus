class Forecast::HomeController < ApplicationController
  def index
    if Sensor::Config.exists?(:inverter_power_forecast)
      render
      # Render HTML page with lazy frame placeholders
    else
      redirect_to root_path
    end
  end

  private

  helper_method def days
    @days ||=
      begin
        max_date =
          Sensor::Query::ForecastAvailability.new(
            :inverter_power_forecast,
            :outdoor_temp_forecast,
          ).call(limit: 7.days)

        max_date ? ((max_date - Date.current).to_i + 1).clamp(2..) : nil
      end
  end

  helper_method def timeframe
    return unless days

    @timeframe ||=
      Timeframe.new("#{Date.current}..#{Date.current + (days - 1).days}")
  end

  helper_method def title
    t('forecast.title')
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
