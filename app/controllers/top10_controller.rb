class Top10Controller < ApplicationController
  include ParamsHandling

  def index
    set_meta_tags title: 'Top 10'
  end

  private

  helper_method def field_items
    Senec::POWER_FIELDS.map do |field|
      {
        name: I18n.t("senec.#{field}"),
        field:,
        href: url_for(**permitted_params.merge(field:, only_path: true)),
      }
    end
  end

  helper_method def nav_items
    [
      {
        name: t('calculator.peak'),
        href: path_with_period('peak'),
        current: period == 'peak',
      },
      {
        name: t('calculator.day'),
        href: path_with_period('day'),
        current: period == 'day',
      },
      {
        name: t('calculator.week'),
        href: path_with_period('week'),
        current: period == 'week',
      },
      {
        name: t('calculator.month'),
        href: path_with_period('month'),
        current: period == 'month',
      },
      {
        name: t('calculator.year'),
        href: path_with_period('year'),
        current: period == 'year',
      },
    ]
  end

  def path_with_period(period)
    url_for(permitted_params.merge(period:, only_path: true))
  end
end
