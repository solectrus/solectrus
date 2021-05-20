class ApplicationController < ActionController::Base
  private

  helper_method def topnav_items
    [
      {
        name: t('layout.stats'),
        href: root_path
      },
      {
        name: t('layout.top10'),
        href: top10_path( \
          field: respond_to?(:field) && field.in?(Senec::POWER_FIELDS) ? field : 'inverter_power',
          timeframe: respond_to?(:timeframe) && timeframe.in?(%w[day month year]) ? timeframe : 'day'
        )
      },
      {
        name: t('layout.about'),
        href: pages_path('about')
      }
    ]
  end
end
