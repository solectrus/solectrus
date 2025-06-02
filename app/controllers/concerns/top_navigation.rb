module TopNavigation # rubocop:disable Metrics/ModuleLength
  extend ActiveSupport::Concern

  included do # rubocop:disable Metrics/BlockLength
    private

    helper_method def topnav_primary_items
      [
        root_item,
        (inverter_item if Setting.enable_multi_inverter),
        (house_item if Setting.enable_custom_consumer),
        essentials_item,
        top10_item,
      ].compact
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

    def root_item
      {
        name: t('layout.balance'),
        href:
          if helpers.controller_namespace == 'house'
            root_path(sensor: 'house_power', timeframe: helpers.timeframe)
          elsif helpers.controller_namespace == 'inverter'
            root_path(sensor: 'inverter_power', timeframe: helpers.timeframe)
          else
            root_path(sensor: 'inverter_power', timeframe: 'now')
          end,
        current: helpers.controller_namespace == 'balance',
        data: {
          controller: 'tippy',
        },
      }
    end

    def inverter_item
      {
        name: t('layout.inverter'),
        icon: 'solar-panel',
        icon_only: true,
        href: inverter_home_path(sensor: 'inverter_power', timeframe:),
        current: helpers.controller_namespace == 'inverter',
      }
    end

    def house_item
      {
        name: t('layout.house'),
        icon: 'house-crack',
        icon_only: true,
        href: house_home_path(sensor: 'house_power', timeframe:),
        current: helpers.controller_namespace == 'house',
      }
    end

    def essentials_item
      {
        name: t('layout.essentials'),
        icon: 'grip',
        icon_only: true,
        href: essentials_path,
        current: helpers.controller.is_a?(EssentialsController),
      }
    end

    def top10_item
      {
        name: t('layout.top10'),
        icon: 'trophy',
        icon_only: true,
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
      }
    end

    def corresponding_top10_period
      return 'day' unless helpers.respond_to?(:timeframe)

      case helpers.timeframe&.id
      when :week, :month, :year
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
        href: settings_general_path,
        current: helpers.controller_namespace == 'settings',
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
