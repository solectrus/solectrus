class ApplicationController < ActionController::Base
  private

  helper_method def topnav_items
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
    ]
  end
end
