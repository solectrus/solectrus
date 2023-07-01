module TopNavigation
  extend ActiveSupport::Concern

  included do
    private

    helper_method def topnav_items
      [
        # Left
        stats_item,
        top10_item,
        about_item,
        # Right
        faq_item,
        settings_item,
        session_item,
      ]
    end

    def stats_item
      { name: t('layout.stats'), href: root_path }
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
      { name: t('layout.about'), href: 'https://solectrus.de' }
    end

    def faq_item
      {
        name: t('layout.faq'),
        icon: 'circle-question',
        href: 'https://solectrus.de/faq',
        alignment: :right,
      }
    end

    def settings_item
      {
        name: t('layout.settings'),
        icon: 'cog',
        href: prices_path,
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
