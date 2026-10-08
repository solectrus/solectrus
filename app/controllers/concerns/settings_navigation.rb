module SettingsNavigation
  extend ActiveSupport::Concern

  included do
    helper_method def nav_items
      items = [
        { name: t('settings.general.name'), href: settings_general_path },
        { name: t('settings.sensors.name'), href: settings_sensors_path },
        {
          name: Price.human_enum_name(:name, :electricity),
          href: settings_prices_path(name: 'electricity'),
        },
        {
          name: Price.human_enum_name(:name, :feed_in),
          href: settings_prices_path(name: 'feed_in'),
        },
        {
          name: t('settings.cash_flows.name'),
          href: settings_cash_flows_path,
        },
        # The places are a page of the cars (see car_nav_items)
        ({ name: t('settings.cars.name'), href: settings_cars_path, current: controller_name.in?(%w[cars places]) } if Setting.enable_car),
      ].compact

      items.map do |item|
        item.reverse_merge(current: helpers.current_page?(item[:href]))
      end
    end

    # The side navigation of the cars: their names, and their places when the
    # cars have a location. Each page has a URL of its own.
    helper_method def car_nav_items
      items = [{ name: t('settings.cars.vehicles'), href: settings_cars_path }]
      # Without a sponsorship the places show the upsell (see
      # Settings::PlacesController)
      return items unless Sensor::Config.exists?(:car_location, check_policy: false)

      items + [{ name: t('settings.places.name'), href: settings_places_path }]
    end
  end
end
