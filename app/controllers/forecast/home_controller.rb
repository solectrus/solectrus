class Forecast::HomeController < ApplicationController
  # The period of a phone opens the timeframe select here
  include TimeframeSelectModal

  def index
    return redirect_to(root_path) unless Sensor::Config.exists?(:inverter_power_forecast)

    # Render HTML page with lazy frame placeholders
    render
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

  # The period of a phone, as the home pages have it (see
  # Timeframe::Pager::Component). It opens the timeframe select, which marks
  # the forecast. The arrow back to today leads to the page that led here.
  helper_method def pager_items
    {
      period: { name: days ? t('forecast.next_days', count: days) : title, href: forecast_path },
      arrows: { prev: timeframe_page.path('day') },
    }
  end

  def balance_path(timeframe, compare: nil) = balance_home_path(sensor_name: 'inverter_power', timeframe:, compare:)

  # The timeframe select leads to the page that led here, as the tabs do
  helper_method def timeframe_page
    TimeframePage::Sensor.new(
      namespace: origin.fetch('namespace', 'balance'),
      sensor_name: origin.fetch('sensor_name', 'inverter_power'),
      params: origin.fetch('params', {}).symbolize_keys,
    )
  end

  # The home page seen last that leads to the forecast (see
  # HomePageController#remember_forecast_origin). Without one, the power
  # balance of the inverter.
  def origin = session[:forecast_origin] || {}

  def timeframe_select_template = 'timeframe_select'

  helper_method def year_comparison_items
    return [] unless Sensor::Chart::YearComparison.available_for?(Sensor::Registry[:inverter_power])

    Sensor::Chart::YearComparison.variants.map do |variant|
      { name: t(variant::SHORT_LABEL_KEY), href: balance_path('all', compare: variant::PARAM), current: false }
    end
  end

  # The tabs lead to the page that led here, its live view included
  helper_method def nav_items
    %w[now day week month year all].map do |timeframe|
      {
        name: t("data.#{timeframe}"),
        href: (origin['live'] if timeframe == 'now') || timeframe_page.path(timeframe),
        current: false,
      }
    end
  end
end
