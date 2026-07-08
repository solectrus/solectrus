module MainNavigation # rubocop:disable Metrics/ModuleLength
  extend ActiveSupport::Concern

  included do # rubocop:disable Metrics/BlockLength
    private

    helper_method def desktop_primary_items
      [
        root_item,
        (inverter_item if Setting.enable_multi_inverter),
        (
          forecast_item if Setting.enable_forecast &&
            Sensor::Config.exists?(:inverter_power_forecast)
        ),
        (house_item if Setting.enable_custom_consumer),
        (heatpump_item if Setting.enable_heatpump),
        essentials_item,
        top10_item,
        amortization_item,
      ].compact
    end

    helper_method def all_mobile_items
      @all_mobile_items ||=
        [
          root_item,
          (inverter_item if Setting.enable_multi_inverter),
          (house_item if Setting.enable_custom_consumer),
          (heatpump_item if Setting.enable_heatpump),
          (
            forecast_item if Setting.enable_forecast &&
              Sensor::Config.exists?(:inverter_power_forecast)
          ),
          essentials_item,
          top10_item,
          amortization_item,
        ].compact
    end

    helper_method def desktop_secondary_items
      @desktop_secondary_items ||=
        [
          helios_item,
          settings_item,
          registration_item,
          notifications_item,
          locale_switcher_item,
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

    def locale_switcher_item
      { component: LocaleSelector::Component }
    end

    def root_item
      {
        name: t('layout.balance'),
        href:
          case helpers.controller_namespace
          when 'house'
            balance_home_path(
              sensor_name: 'house_power',
              timeframe: computed_timeframe,
            )
          when 'inverter'
            balance_home_path(
              sensor_name: 'inverter_power',
              timeframe: computed_timeframe,
            )
          when 'heatpump'
            balance_home_path(
              sensor_name: 'heatpump_power',
              timeframe: computed_timeframe,
            )
          else
            balance_home_path
          end,
        current: helpers.controller_namespace == 'balance',
        data: {
          controller: 'tooltip force-reload',
          action: 'click->force-reload#perform',
        },
      }
    end

    def inverter_item
      {
        name: t('layout.inverter'),
        icon: 'solar-panel',
        icon_only: true,
        href: inverter_home_path(sensor_name: 'inverter_power', timeframe: computed_timeframe),
        current: helpers.controller_namespace == 'inverter',
      }
    end

    def house_item
      {
        name: t('layout.house'),
        icon: 'house-crack',
        icon_only: true,
        href: house_home_path(sensor_name: 'house_power', timeframe: computed_timeframe),
        current: helpers.controller_namespace == 'house',
      }
    end

    def heatpump_item
      {
        name: t('layout.heatpump'),
        icon: 'fan',
        icon_only: true,
        href:
          heatpump_home_path(sensor_name: 'heatpump_heating_power', timeframe: computed_timeframe),
        current: helpers.controller_namespace == 'heatpump',
      }
    end

    def amortization_item
      # Shown to everyone (not just admins) so the feature is discoverable;
      # non-admins land on a hint to log in when the calculation isn't public.
      return unless Setting.enable_amortization

      {
        name: t('layout.amortization'),
        icon: 'sack-dollar',
        icon_only: true,
        href: amortization_path,
        current: helpers.controller_namespace == 'amortization',
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
            sensor_name:
              if helpers.respond_to?(:sensor_name) &&
                   helpers.sensor_name.in?(
                     Sensor::Config.top10_sensors.map(&:name),
                   )
                helpers.sensor_name
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

    def forecast_item
      {
        name: t('layout.forecast'),
        icon: 'magic-wand-sparkles',
        icon_only: true,
        href: forecast_path,
        current: helpers.controller_namespace == 'forecast',
      }
    end

    def computed_timeframe
      if helpers.controller_namespace == 'forecast'
        'day'
      elsif helpers.respond_to?(:timeframe)
        helpers.timeframe
      end
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

    def notifications_item
      any, unread_count = Notification.stats
      return unless any

      {
        name: t('layout.notifications'),
        href: notifications_path,
        icon: 'message',
        badge_count: unread_count,
        badge_data: { notification_badge: true },
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

    def helios_item
      return unless HeliosCheck.available?

      {
        name: t('layout.helios'),
        icon: 'sun',
        href: HeliosCheck.browser_url(request),
      }
    end

    def settings_item
      {
        name: t('layout.settings'),
        icon: 'gear',
        href: settings_general_path,
        current: helpers.controller_namespace == 'settings',
      }
    end

    def session_item
      if helpers.admin?
        {
          name: t('layout.logout'),
          icon: 'arrow-right-from-bracket',
          href: session_path(return_to: logout_return_to),
          data: {
            'turbo-method': :delete,
          },
        }
      else
        {
          name: t('layout.login'),
          icon: 'arrow-right-to-bracket',
          href: new_session_path,
        }
      end
    end

    # Return to the current page after logout - unless it requires admin, in
    # which case the now non-admin user would only hit a 403 there. Fall back
    # to the homepage (via a blank return_to) for those pages.
    def logout_return_to
      return if admin_only_page?

      request.fullpath
    end

    def admin_only_page?
      self.class._process_action_callbacks.any? do |callback|
        callback.kind == :before && callback.filter == :admin_required!
      end
    end
  end
end
