module Sensor
  module Query
    # Service for finding peak power values across multiple sensors.
    #
    # This service queries for maximum power values from configured sensors
    # since a given start date.
    #
    # Usage:
    #   service = Sensor::Query::PowerPeak.new([:inverter_power, :house_power], timeframe: Timeframe.new("P30D"))
    #   peaks = service.call
    #   # => { inverter_power: 5000, house_power: 3500 }
    class PowerPeak < Base
      def initialize(sensor_names, timeframe: Timeframe.new('P30D'))
        super(Array(sensor_names), timeframe)
      end

      def call
        data_instance = super
        return if data_instance.nil? || data_instance.raw_data.blank?

        # Extract raw hash from Data instance for backward compatibility
        result = data_instance.raw_data.dup

        # Add total inverter power if custom inverter sensors are present
        add_total_inverter_power(result)

        result
      end

      protected

      def fetch_raw_data
        Rails
          .cache
          .fetch(cache_key, **cache_options) do
            query_peak_values.symbolize_keys.presence || {}
          end
      end

      def create_data_instance(raw_data, timeframe)
        # PowerPeak needs to return a proper Data instance for Base compatibility
        Sensor::Data::Single.new(raw_data, timeframe:)
      end

      def query_type
        :power_peak
      end

      private

      def query_peak_values
        return {} if sensor_names_with_max.empty?

        SummaryValue
          .where(
            date:
              timeframe.effective_beginning_date..timeframe.effective_ending_date,
            field: sensor_names_with_max,
            aggregation: :max,
          )
          .group(:field)
          .maximum(:value)
      end

      def sensor_names_with_max
        @sensor_names_with_max ||=
          available_sensors.select do |name|
            Sensor::Registry[name].summary_aggregations.include?(:max)
          end
      end

      def add_total_inverter_power(result)
        return if result[:inverter_power] # Already has total

        # Sum up any custom inverter sensors in the result
        total =
          Sensor::Config.custom_inverter_sensors.sum do |sensor|
            result[sensor.name] || 0
          end

        result[:inverter_power] = total if total.positive?
      end

      def cache_options
        { expires_in: 1.day, skip_nil: true }
      end

      def cache_key
        @cache_key ||=
          begin
            sorted = sensor_names_with_max.sort.join(',')
            "power_peak:v5:#{timeframe}:#{Digest::SHA256.hexdigest(sorted)}"
          end
      end
    end
  end
end
