module TopNavigation # rubocop:disable Metrics/ModuleLength
  extend ActiveSupport::Concern

  included do # rubocop:disable Metrics/BlockLength
    private

    helper_method def topnav_items
      [
        # Left
        stats_item,
        essentials_item,
        top10_item,
        about_item,
        # Right
        faq_item,
        settings_item,
        expand_item,
        compress_item,
        registration_item,
        session_item,
      ].compact
    end

    def stats_item
      { name: t('layout.balance'), href: root_path }
    end

    def essentials_item
      { name: t('layout.essentials'), href: essentials_path }
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
        target: '_blank',
      }
    end

    def registration_item
      return unless Rails.configuration.x.registration_required
      return unless helpers.admin?
      return if helpers.registration_banner?

      {
        name: t('layout.registration'),
        href: registration_path,
        icon: 'id-card',
        alignment: :right,
        data: {
          turbo: 'false',
        },
      }
    end

    def expand_item
      {
        name: t('layout.fullscreen_on'),
        icon: 'expand',
        alignment: :right,
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
        alignment: :right,
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
        target: '_blank',
        alignment: :right,
      }
    end

    def settings_item
      {
        name: t('layout.settings'),
        icon: 'cog',
        href: settings_path,
        alignment: :right,
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
          alignment: :right,
        }
      else
        {
          name: t('layout.login'),
          icon: 'arrow-right-to-bracket',
          href: new_session_path,
          data: {
            turbo_frame: 'modal',
          },
          alignment: :right,
        }
      end
    end
  end
end
