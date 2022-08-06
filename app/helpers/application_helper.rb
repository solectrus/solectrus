module ApplicationHelper
  def title
    case period
    when 'now'
      'Live'
    when 'day'
      l(timestamp, format: :default)
    when 'week'
      "KW #{timestamp.cweek}, #{timestamp.year}"
    when 'month'
      l(timestamp, format: :month)
    when 'year'
      timestamp.year.to_s
    when 'all'
      'Seit Installation'
    end
  end

  def topnav_items
    [
      { name: t('layout.stats'), href: root_path },
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
              if respond_to?(:period) && period.in?(%w[day month year])
                period
              else
                'day'
              end,
          ),
      },
      { name: t('layout.about'), href: about_path },
      session_item,
    ]
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
