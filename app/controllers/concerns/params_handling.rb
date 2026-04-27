module ParamsHandling
  extend ActiveSupport::Concern

  ALLOWED_INTERVALS = {
    '1m' => 1.minute,
    '5m' => 5.minutes,
    '15m' => 15.minutes,
    '1h' => 1.hour,
  }.freeze
  private_constant :ALLOWED_INTERVALS

  included do
    private

    helper_method def permitted_params
      @permitted_params ||=
        params.permit(
          :sensor_name,
          :timeframe,
          :period,
          :sort,
          :calc,
          :interval,
        )
    end

    helper_method def period
      permitted_params[:period]
    end

    helper_method def sensor_name
      permitted_params[:sensor_name]&.to_sym
    end

    helper_method def sensor
      return unless sensor_name

      Sensor::Registry[sensor_name]
    end

    helper_method def calc
      permitted_params[:calc]
    end

    helper_method def sort
      return if permitted_params[:sort].blank?

      ActiveSupport::StringInquirer.new(permitted_params[:sort])
    end

    helper_method def interval
      return unless timeframe&.day?

      ALLOWED_INTERVALS[permitted_params[:interval]]
    end

    helper_method def timeframe
      return if permitted_params[:timeframe].blank?

      @timeframe ||= Timeframe.new(permitted_params[:timeframe])
    end

    helper_method def data
      # Requires the including controller to define
      # both `data_now` and `data_range` methods
      @data ||= timeframe.now? ? data_now : data_range
    end
  end
end
