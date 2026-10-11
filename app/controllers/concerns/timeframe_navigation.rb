module TimeframeNavigation
  extend ActiveSupport::Concern

  included do
    private

    helper_method def title
      timeframe.localized
    end

    def path_with_timeframe(timeframe, sensor_name: chart_sensor_name)
      url_for(
        controller: "#{helpers.controller_namespace}/home",
        sensor_name:,
        timeframe:,
        action: 'index',
        **selection_params,
      )
    end

    # The chart that the links to the other timeframes keep
    def chart_sensor_name = sensor_name

    # The live view of a page without a chart has no sensor in its address
    # (see Sensor::HomePage.live_chart?), so its link needs no redirect
    def live_sensor_name
      chart_sensor_name if Sensor::HomePage.live_chart?(helpers.controller_namespace.to_sym)
    end

    helper_method def nav_items
      [
        {
          name: t('data.now'),
          href: path_with_timeframe('now', sensor_name: live_sensor_name),
          current: timeframe.now?,
        },
        {
          name: t('data.day'),
          href: path_with_timeframe(timeframe.corresponding_day),
          current: timeframe.day_like?,
        },
        {
          name: t('data.week'),
          href: path_with_timeframe(timeframe.corresponding_week),
          current: timeframe.week_like?,
        },
        {
          name: t('data.month'),
          href: path_with_timeframe(timeframe.corresponding_month),
          current: timeframe.month_like?,
        },
        {
          name: t('data.year'),
          href: path_with_timeframe(timeframe.corresponding_year),
          current: timeframe.year_like?,
        },
        {
          name: t('data.all'),
          href: path_with_timeframe(timeframe.corresponding_all),
          current: timeframe.all_like?,
        },
      ]
    end
  end
end
