module ParamsHandling
  extend ActiveSupport::Concern

  included do
    private

    helper_method def permitted_params
      @permitted_params ||=
        params.permit(:sensor, :timeframe, :period, :sort, :calc)
    end

    helper_method def period
      permitted_params[:period]
    end

    helper_method def sensor
      permitted_params[:sensor]&.to_sym
    end

    helper_method def calc
      permitted_params[:calc]
    end

    helper_method def sort
      return if permitted_params[:sort].blank?

      ActiveSupport::StringInquirer.new(permitted_params[:sort])
    end

    helper_method def timeframe
      return if permitted_params[:timeframe].blank?

      @timeframe ||= Timeframe.new(permitted_params[:timeframe])
    end

    helper_method def calculator
      @calculator ||=
        if timeframe.now?
          Calculator::Now.new
        else
          # Requires a method `calculations` in the controller
          Calculator::Range.new(timeframe, calculations:)
        end
    end
  end
end
