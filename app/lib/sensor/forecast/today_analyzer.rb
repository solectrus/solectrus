module Sensor
  module Forecast
    # Analyzes forecast data for "today" to determine display logic
    class TodayAnalyzer
      def initialize(forecast_data, current_time: Time.current)
        @forecast_data = forecast_data || {}
        @current_time = current_time
      end

      attr_reader :forecast_data, :current_time

      # Returns true if "today" should be shown in the forecast
      def show_today?
        return true if forecast_data.empty? # Default to true if no data

        # Show today if there's any data for today (past or future)
        today_entries.any?
      end

      # Returns true if there was already production today
      def past_production?
        today_entries.any? do |timestamp, value|
          past?(timestamp) && positive?(value)
        end
      end

      # Calculates remaining Wh from now until end of day
      def remaining_wh
        @remaining_wh ||= calculate_remaining_wh
      end

      # Calculates total Wh for today (past + future)
      def total_wh
        @total_wh ||= calculate_total_wh
      end

      private

      def today_entries
        @today_entries ||=
          forecast_data.select { |timestamp, _| today?(timestamp) }
      end

      def future_forecast_power_expected?
        today_entries.any? do |timestamp, value|
          future?(timestamp) && positive?(value)
        end
      end

      def today?(timestamp)
        timestamp.to_date == Date.current
      end

      def future?(timestamp)
        timestamp > current_time
      end

      def past?(timestamp)
        timestamp <= current_time
      end

      def positive?(value)
        value&.positive?
      end

      def calculate_remaining_wh
        future_entries =
          today_entries.select { |timestamp, _| future?(timestamp) }
        return 0 if future_entries.empty?

        EnergyCalculator.calculate_wh(future_entries.to_a)
      end

      def calculate_total_wh
        return 0 if today_entries.empty?

        EnergyCalculator.calculate_wh(today_entries.to_a)
      end
    end
  end
end
