# The settings group by what they set up: the PV system, the tariffs, the
# sensors, the cars and the system. A section with several pages has them as
# tabs at the side on the desktop and one level down on a phone.
module SettingsNavigation
  extend ActiveSupport::Concern

  included do
    helper_method def nav_items
      @nav_items ||= [
        {
          name: t('settings.plant.name'),
          href: edit_settings_plant_path,
          icon: 'solar-panel',
          current: controller_name.in?(%w[plants cash_flows]),
        },
        # A phone opens the list of the tariffs, the desktop the first one
        {
          name: t('settings.tariffs.name'),
          href: settings_tariffs_path,
          desktop_href: tariff_nav_items.first[:href],
          icon: 'file-invoice',
          current: controller_name.in?(%w[tariffs prices]),
        },
        # On a phone, the sensors and the system form a group of their own. A
        # phone opens the list of the sensor groups, the desktop the first one.
        {
          name: t('settings.sensors.name'),
          href: settings_sensors_path,
          desktop_href: section_settings_sensors_path('generators'),
          icon: 'sliders',
          current: controller_name == 'sensors',
          technical: true,
        },
        (if Sensor::HomePage.available?(:cars)
           {
             name: t('settings.cars.name'),
             href: settings_cars_path,
             icon: 'car',
             current: controller_name.in?(%w[cars places car_payments]),
           }
         end),
        {
          name: t('settings.system.name'),
          href: settings_system_path,
          icon: 'gear',
          technical: true,
        },
      ].compact.map do |item|
        item.reverse_merge(current: helpers.current_page?(item[:href]))
      end
    end

    # The pages of the PV system: its data, and its cash flows for the
    # amortization
    helper_method def plant_nav_items
      [
        { name: t('settings.plant.data'), href: edit_settings_plant_path, icon: 'solar-panel' },
        { name: t('settings.cash_flows.name'), href: settings_cash_flows_path, icon: 'piggy-bank' },
      ]
    end

    # The pages of the tariffs: the price of the grid and the price of the
    # feed-in
    helper_method def tariff_nav_items
      [
        { name: Price.human_enum_name(:name, :electricity), href: settings_prices_path(name: 'electricity'), icon: 'bolt' },
        { name: Price.human_enum_name(:name, :feed_in), href: settings_prices_path(name: 'feed_in'), icon: 'hand-holding-dollar' },
      ]
    end

    # The side navigation of the cars: their names, their payments when the
    # comparison has fuel prices (see Car::Comparison.available?), and their
    # places when the cars have a location. Each page has a URL of its own.
    helper_method def car_nav_items
      items = [
        { name: t('settings.cars.vehicles'), href: settings_cars_path },
        ({ name: t('settings.car_payments.name'), href: settings_car_payments_path } if Car::Comparison.available?),
      ].compact
      # Without a sponsorship the places show the upsell (see
      # Settings::PlacesController)
      return items unless Sensor::Cars.configured_numbers.any? { Sensor::Cars.located?(it, check_policy: false) }

      items + [{ name: t('settings.places.name'), href: settings_places_path }]
    end
  end
end
