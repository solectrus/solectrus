module TopNavigation # rubocop:disable Metrics/ModuleLength
  extend ActiveSupport::Concern

  included do # rubocop:disable Metrics/BlockLength
    private

    helper_method def topnav_primary_items
      [
        house_item,
        heatpump_item,
        # TODO: Enable this later!
        # car_item,
        essentials_item,
        top10_item,
      ]
    end

    helper_method def topnav_secondary_items
      [
        settings_item,
        registration_item,
        ___,
        expand_item,
        compress_item,
        ___,
        docs_item,
        about_item,
        ___,
        session_item,
      ].compact
    end

    def ___
      { name: '-' }
    end

    def house_item
      {
        name: t('layout.house'),
        text: false,
        icon: 'home',
        href: house_home_path(sensor: 'house_power', timeframe:),
        current: helpers.controller.is_a?(House::HomeController),
        data: {
          controller: 'tippy',
        },
      }
    end

    def heatpump_item
      {
        name: t('layout.heatpump'),
        text: false,
        icon: 'fan',
        href: heatpump_home_path(sensor: 'heatpump_heating_power', timeframe:),
        current: helpers.controller.is_a?(Heatpump::HomeController),
        data: {
          controller: 'tippy',
        },
      }
    end

    def car_item
      {
        name: t('layout.car'),
        text: false,
        icon: 'car',
        href: car_home_path(sensor: 'car_driving_distance', timeframe:),
        current: helpers.controller.is_a?(Car::HomeController),
        data: {
          controller: 'tippy',
        },
      }
    end

    def essentials_item
      {
        name: t('layout.essentials'),
        text: false,
        icon: 'grip',
        href: essentials_path,
        current: helpers.controller.is_a?(EssentialsController),
        data: {
          controller: 'tippy',
        },
      }
    end

    def top10_item
      {
        name: t('layout.top10'),
        text: false,
        icon: 'trophy',
        href:
          top10_path(
            sensor:
              if helpers.respond_to?(:sensor) &&
                   helpers.sensor.in?(SensorConfig::POWER_SENSORS)
                helpers.sensor
              else
                'inverter_power'
              end,
            period: corresponding_top10_period,
            sort: 'desc',
            calc: 'sum',
          ),
        current: helpers.controller.is_a?(Top10Controller),
        data: {
          controller: 'tippy',
        },
      }
    end

    def corresponding_top10_period
      return 'day' unless helpers.respond_to?(:timeframe)

      case helpers.timeframe&.id
      when :day, :week, :month, :year
        helpers.timeframe.id
      else
        :day
      end
    end

    def about_item
      {
        name: t('layout.about'),
        href: 'https://solectrus.de',
        icon: 'circle-info',
      }
    end

    def registration_item
      return unless helpers.admin?

      {
        name:
          (
            if UpdateCheck.prompt?
              t('layout.registration_and_sponsoring')
            else
              t('layout.registration')
            end
          ),
        href: registration_path,
        icon: 'id-card',
        data: {
          turbo: 'false',
        },
      }
    end

    def expand_item
      {
        name: t('layout.fullscreen_on'),
        icon: 'expand',
        data: {
          'fullscreen-target' => 'btnOn',
          :action => 'click->fullscreen#on',
        },
      }
    end

    def compress_item
      {
        name: t('layout.fullscreen_off'),
        icon: 'compress',
        data: {
          'fullscreen-target' => 'btnOff',
          :action => 'click->fullscreen#off',
        },
      }
    end

    def docs_item
      {
        name: t('layout.docs'),
        icon: 'circle-question',
        href: 'https://docs.solectrus.de',
      }
    end

    def settings_item
      {
        name: t('layout.settings'),
        icon: 'cog',
        href: settings_path,
        current:
          helpers.controller.is_a?(SettingsController) ||
            helpers.controller.is_a?(PricesController),
      }
    end

    def session_item
      if helpers.admin?
        {
          name: t('layout.logout'),
          icon: 'arrow-right-from-bracket',
          href: session_path,
          data: {
            'turbo-method': :delete,
          },
        }
      else
        {
          name: t('layout.login'),
          icon: 'arrow-right-to-bracket',
          href: new_session_path,
          data: {
            turbo_frame: 'modal',
          },
        }
      end
    end
  end
end
