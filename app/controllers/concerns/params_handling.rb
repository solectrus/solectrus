module ParamsHandling
  extend ActiveSupport::Concern

  included do
    private

    helper_method def permitted_params
      @permitted_params ||= params.permit(:field, :period, :timestamp, :chart)
    end

    helper_method def period
      permitted_params[:period]
    end

    helper_method def field
      permitted_params[:field]
    end

    helper_method def timestamp?
      permitted_params[:timestamp].present?
    end

    helper_method def timestamp
      if period == 'now'
        Time.current
      elsif (param = permitted_params[:timestamp])
        Date.iso8601(param)
      else
        default_timestamp
      end
    end

    def default_timestamp
      case period
      when 'now', 'day'
        Date.current
      when 'week'
        Date.current.beginning_of_week
      when 'month'
        Date.current.beginning_of_month
      when 'year'
        Date.current.beginning_of_year
      when 'all'
        Rails.configuration.x.installation_date.beginning_of_year
      end
    end

    def min_timestamp
      case period
      when 'day'
        Rails.configuration.x.installation_date.beginning_of_day
      when 'week'
        Rails.configuration.x.installation_date.beginning_of_week
      when 'month'
        Rails.configuration.x.installation_date.beginning_of_month
      when 'year'
        Rails.configuration.x.installation_date.beginning_of_year
      end
    end

    helper_method def out_of_range?(date = timestamp)
      return unless date && min_timestamp

      date < min_timestamp || date > default_timestamp + 1.day
    end

    helper_method def corresponding_day
      return unless timestamp

      [Rails.configuration.x.installation_date, timestamp.to_date].max
    end

    helper_method def corresponding_month
      return unless timestamp

      [
        Rails.configuration.x.installation_date.beginning_of_month,
        timestamp.beginning_of_month.to_date,
      ].max
    end

    helper_method def corresponding_year
      return unless timestamp

      [
        Rails.configuration.x.installation_date.beginning_of_year,
        timestamp.beginning_of_year.to_date,
      ].max
    end

    helper_method def corresponding_week
      return unless timestamp

      [
        Rails.configuration.x.installation_date.beginning_of_week,
        timestamp.beginning_of_week.to_date,
      ].max
    end
  end
end
