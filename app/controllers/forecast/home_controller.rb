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
