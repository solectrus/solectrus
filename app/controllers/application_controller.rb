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
          field: field.in?(Senec::POWER_FIELDS) ? field : 'inverter_power',
          timeframe: timeframe.in?(%w[day month year]) ? timeframe : 'day'
        )
      }
    ]
  end
end
