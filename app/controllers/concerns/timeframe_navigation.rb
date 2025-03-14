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
        sensor:,
        timeframe:,
        action: 'index',
      )
    end

    helper_method def nav_items
      [
        {
          name: t('calculator.now'),
          href: path_with_timeframe('now'),
          current: timeframe.now?,
        },
        {
          name: t('calculator.day'),
          href: path_with_timeframe(timeframe.corresponding_day),
          current: timeframe.day?,
        },
        {
          name: t('calculator.week'),
          href: path_with_timeframe(timeframe.corresponding_week),
          current: timeframe.week_like?,
        },
        {
          name: t('calculator.month'),
          href: path_with_timeframe(timeframe.corresponding_month),
          current: timeframe.month_like?,
        },
        {
          name: t('calculator.year'),
          href: path_with_timeframe(timeframe.corresponding_year),
          current: timeframe.year_like?,
        },
        {
          name: t('calculator.all'),
          href: path_with_timeframe('all'),
          current: timeframe.all?,
        },
      ]
    end
  end
end
