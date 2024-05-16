module TopNavigation # rubocop:disable Metrics/ModuleLength
  extend ActiveSupport::Concern

  included do # rubocop:disable Metrics/BlockLength
    private

    helper_method def topnav_primary_items
      [stats_item, essentials_item, top10_item]
    end

    helper_method def topnav_secondary_items
      [
        settings_item,
        registration_item,
        ___,
        expand_item,
        compress_item,
        ___,
        faq_item,
        about_item,
        ___,
        session_item,
      ].compact
    end

    def ___
      { name: '-' }
    end

    def stats_item
      {
        name: t('layout.balance'),
        href: root_path,
        current: helpers.controller.is_a?(HomeController),
      }
    end

    def essentials_item
      {
        name: t('layout.essentials'),
        href: essentials_path,
        current: helpers.controller.is_a?(EssentialsController),
      }
    end

    def top10_item
      {
        name: t('layout.top10'),
        href:
          top10_path(
            field:
              if helpers.respond_to?(:field) &&
                   helpers.field.in?(Senec::POWER_FIELDS)
                helpers.field
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
      return if helpers.registration_banner?

      {
        name:
          (
            if UpdateCheck.instance.prompt?
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
        extra: registration_extra,
      }
    end

    def registration_extra
      if UpdateCheck.instance.sponsoring?
        helpers.tag.p(
          I18n.t('layout.thanks_for_sponsoring'),
          class: 'text-green-600',
        )
      elsif UpdateCheck.instance.prompt?
        helpers.tag.p(
          I18n.t('layout.prompt_for_sponsoring'),
          class: 'text-yellow-600',
        )
      end
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

    def faq_item
      {
        name: t('layout.faq'),
        icon: 'circle-question',
        href: 'https://solectrus.de/faq',
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
