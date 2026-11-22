class Forecast::HomeController < ApplicationController
  # The period of a phone opens the timeframe select here
  include TimeframeSelectModal

  # The page shows today and tomorrow first, the days after them on request
  SHORT_DAYS = 2
  private_constant :SHORT_DAYS

  def index
    return redirect_to(root_path) unless Sensor::Config.exists?(:inverter_power_forecast)
    return redirect_to(forecast_path) if full? && !more_days?

    # Render HTML page with lazy frame placeholders
    render
  end

  private

  # Only the route /forecast/full sets it, not a query parameter
  def full? = request.path_parameters[:range] == 'full'

  # Whether the forecast has days after tomorrow
  def more_days? = available_days.to_i > SHORT_DAYS

  helper_method def days
    full? ? available_days : (SHORT_DAYS if available_days)
  end

  # The days the forecast has: today and up to 7 more, as far as the query
  # looks ahead. A day counts once the forecast reaches its afternoon.
  def available_days
    return @available_days if defined?(@available_days)

    max_date =
      Sensor::Query::ForecastAvailability.new(
        :inverter_power_forecast,
        :outdoor_temp_forecast,
      ).call(limit: 7.days)

    @available_days = max_date ? ((max_date - Date.current).to_i + 1).clamp(SHORT_DAYS..) : nil
  end

  def period_name
    return title unless days

    full? ? t('forecast.next_days', count: days) : t('forecast.today_and_tomorrow')
  end

  helper_method def timeframe
    return unless days

    @timeframe ||=
      Timeframe.new("#{Date.current}..#{Date.current + (days - 1).days}")
  end

  helper_method def title
    t('forecast.title')
  end

  # The period, as the home pages have it (see Timeframe::Pager::Component).
  # It opens the timeframe select, which marks the forecast. The arrows lead
  # from today to today and tomorrow, and from there to the full forecast.
  # Back from today and tomorrow is the page that led here.
  helper_method def pager_items
    {
      period: { name: period_name, href: forecast_path },
      arrows: {
        prev: full? ? forecast_path : timeframe_page.path('day'),
        next: (forecast_full_path if !full? && more_days?),
      },
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
