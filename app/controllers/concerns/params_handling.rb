module ParamsHandling
  extend ActiveSupport::Concern

  included do
    private

    helper_method def permitted_params
      @permitted_params ||= params.permit(:field, :timeframe, :timestamp, :chart)
    end

    helper_method def timeframe
      permitted_params[:timeframe]
    end

    helper_method def field
      permitted_params[:field]
    end

    helper_method def timestamp?
      permitted_params[:timestamp].present?
    end

    helper_method def timestamp
      if (result = permitted_params[:timestamp])
        Date.iso8601(result).beginning_of_day
      else
        default_timestamp
      end
    end

    def default_timestamp
      case timeframe
      when 'now'   then Time.current
      when 'day'   then Time.current.beginning_of_day
      when 'week'  then Time.current.beginning_of_week
      when 'month' then Time.current.beginning_of_month
      when 'year'  then Time.current.beginning_of_year
      when 'all'   then Rails.configuration.x.installation_date.beginning_of_year.in_time_zone
      end
    end
  end
end
