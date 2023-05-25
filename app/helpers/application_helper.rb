module ApplicationHelper
  def title
    timeframe.now? ? 'Live' : timeframe.localized
  end

  def topnav_items
    [
      { name: t('layout.stats'), href: root_path },
      top10_item,
      {
        name: t('layout.settings'),
        icon: 'cog',
        href: prices_path,
        alignment: :right,
      },
      { name: t('layout.about'), href: 'https://solectrus.de' },
      session_item,
    ]
  end

  def top10_item
    {
      name: t('layout.top10'),
      href:
        top10_path(
          field:
            if respond_to?(:field) && field.in?(Senec::POWER_FIELDS)
              field
            else
              'inverter_power'
            end,
          period:
            if respond_to?(:timeframe) && timeframe&.id.in?(%i[day month year])
              timeframe.id
            else
              'day'
            end,
          sort: 'desc',
        ),
    }
  end

  def session_item
    if admin?
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
