class Top10Controller < ApplicationController
  include ParamsHandling

  def index
    set_meta_tags title: 'Top 10', noindex: true, nofollow: true
  end

  private

  helper_method def field_items
    Senec::POWER_FIELDS.map do |field|
      {
        name: I18n.t("senec.#{field}"),
        field: field,
        href: url_for(**permitted_params.merge(field: field), only_path: true)
      }
    end
  end

  helper_method def timeframe_items
    [
      { name: t('calculator.day'),   href: url_for(permitted_params.merge(timeframe: 'day')) },
      { name: t('calculator.month'), href: url_for(permitted_params.merge(timeframe: 'month')) },
      { name: t('calculator.year'),  href: url_for(permitted_params.merge(timeframe: 'year')) }
    ]
  end
end
