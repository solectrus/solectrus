class Top10Controller < ApplicationController
  include ParamsHandling

  def index
    redirect_to(default_path) unless period && field && calc && sort
  end

  private

  helper_method def title
    t('layout.top10')
  end

  def default_path
    top10_path(
      period: period || 'day',
      field: field || 'inverter_power',
      calc: calc || 'sum',
      sort: sort || 'desc',
    )
  end

  helper_method def field_items
    Senec::POWER_FIELDS.map do |field|
      MenuItem::Component.new(
        name: I18n.t("senec.#{field}"),
        href: url_for(**permitted_params.merge(field:, only_path: true)),
        data: {
          action: 'dropdown--component#toggle',
        },
        field:,
        current: field == self.field,
      )
    end
  end

  helper_method def nav_items
    [
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
