module SettingsNavigation
  extend ActiveSupport::Concern

  included do
    helper_method def nav_items
      @nav_items ||= [
        {
          name: t('settings.general.name'),
          href: settings_general_path,
          icon: 'gear',
        },
        {
          name: t('settings.sensors.name'),
          href: settings_sensors_path,
          icon: 'sliders',
        },
        {
          name: Price.human_enum_name(:name, :electricity),
          href: settings_prices_path(name: 'electricity'),
          icon: 'file-invoice',
        },
        {
          name: Price.human_enum_name(:name, :feed_in),
          href: settings_prices_path(name: 'feed_in'),
          icon: 'hand-holding-dollar',
        },
        {
          name: t('settings.cash_flows.name'),
          href: settings_cash_flows_path,
          icon: 'piggy-bank',
        },
      ].map do |item|
        item.merge(current: helpers.current_page?(item[:href]))
      end
    end
  end
end
