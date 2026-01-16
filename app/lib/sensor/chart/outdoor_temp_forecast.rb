module Sensor
  module Chart
    class OutdoorTempForecast < Base
      include Concerns::Forecast

      FORECAST_SENSOR_NAMES = %i[outdoor_temp outdoor_temp_forecast].freeze
      public_constant :FORECAST_SENSOR_NAMES

      private

      def forecast_sensor_name
        :outdoor_temp_forecast
      end

      def transform_data(data_values, sensor_name)
        return super unless sensor_name == :outdoor_temp_forecast

        # Set past and current values to nil (keeps timestamps but hides line in past)
        # This prevents overlap with actual temperature line
        now = Time.current
        points =
          series.public_send(sensor_name, *aggregations_for_sensor(sensor_name))

        points.map do |time_key, value|
          normalize_timestamp(time_key) > now ? value : nil
        end
      end

      def add_series_boundaries!(series_raw_data)
        Sensor::Forecast::BoundaryAdjuster.add_edge_boundaries!(series_raw_data)
      end

      def build_day_aggregation(date, entries)
        Sensor::Forecast::TemperatureAggregator.new(
          date,
          entries,
          actual_temp_data,
          forecast_sensor_data,
        ).call
      end

      def actual_temp_data
        @actual_temp_data ||= extract_sensor_data(:outdoor_temp)
      end

      def label_builder
        @label_builder ||=
          Sensor::Forecast::LabelBuilder.new(
            forecast_data,
            today_analyzer,
            value_key: :avg_temp,
          )
      end

      def style_for_sensor(sensor)
        case sensor.name
        when :outdoor_temp
          # Actual temperature: solid line with fill
          super.merge(fill: true, borderWidth: 2)
        else
          # Forecast: line without fill
          super.merge(fill: false, borderWidth: 2)
        end
      end
    end
  end
end
