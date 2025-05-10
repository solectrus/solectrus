module SettingsNavigation
  extend ActiveSupport::Concern

  included do
    helper_method def nav_items
      items = [
        { name: t('settings.general.name'), href: settings_general_path },
        {
          name: Price.human_enum_name(:name, :electricity),
          href: settings_prices_path(name: 'electricity'),
        },
        {
          name: Price.human_enum_name(:name, :feed_in),
          href: settings_prices_path(name: 'feed_in'),
        },
        { name: t('settings.sensors.name'), href: settings_sensors_path },
      ]

      items.map do |item|
        item.merge(current: helpers.current_page?(item[:href]))
      end
    end
  end
end
