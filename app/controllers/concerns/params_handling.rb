module ParamsHandling
  extend ActiveSupport::Concern

  included do
    private

    helper_method def permitted_params
      @permitted_params ||= params.permit(:field, :timeframe, :period, :sort)
    end

    helper_method def period
      permitted_params[:period]
    end

    helper_method def field
      permitted_params[:field]
    end

    helper_method def sort
      ActiveSupport::StringInquirer.new(permitted_params[:sort])
    end

    helper_method def timeframe
      @timeframe ||=
        Timeframe.new(
          permitted_params[:timeframe] || 'now',
          min_date: Rails.application.config.x.installation_date,
          allowed_days_in_future: 6,
        )
    end
  end
end
