class Top10Controller < ApplicationController
  def index
    set_meta_tags title: 'Top 10', noindex: true, nofollow: true
  end

  private

  helper_method def permitted_params
    @permitted_params ||= params.permit(:field, :timeframe)
  end

  helper_method def timeframe
    permitted_params[:timeframe]
  end

  helper_method def field
    permitted_params[:field]
  end

  helper_method def field_items
    Senec::POWER_FIELDS.map do |field|
      [
        I18n.t("senec.#{field}"),
        field,
        url_for(**permitted_params.merge(field: field), only_path: true)
      ]
    end
  end

  helper_method def timeframe_items
    [
      [ t('calculator.day'),   url_for(permitted_params.merge(timeframe: 'day')) ],
      [ t('calculator.week'),  url_for(permitted_params.merge(timeframe: 'week')) ],
      [ t('calculator.month'), url_for(permitted_params.merge(timeframe: 'month')) ],
      [ t('calculator.year'),  url_for(permitted_params.merge(timeframe: 'year')) ]
    ]
  end
end
