module TimeframeNavigation
  extend ActiveSupport::Concern

  included do
    private

    helper_method def title
      timeframe.now? ? 'Live' : timeframe.localized
    end

    def path_with_timeframe(timeframe)
      url_for(
        controller: "#{helpers.controller_namespace}/home",
        sensor_name:,
        timeframe:,
        action: 'index',
      )
    end

    helper_method def nav_items
      [
        {
          name: t('data.now'),
          href: path_with_timeframe('now'),
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
