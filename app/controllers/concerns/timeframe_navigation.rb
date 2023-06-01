module TimeframeNavigation
  extend ActiveSupport::Concern

  included do
    private

    def title
      timeframe.now? ? 'Live' : timeframe.localized
    end

    def path_with_timeframe(timeframe)
      root_path(field:, timeframe:)
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
          current: timeframe.week?,
        },
        {
          name: t('calculator.month'),
          href: path_with_timeframe(timeframe.corresponding_month),
          current: timeframe.month?,
        },
        {
          name: t('calculator.year'),
          href: path_with_timeframe(timeframe.corresponding_year),
          current: timeframe.year?,
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
