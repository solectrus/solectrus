module Sensor
  module Chart
    class InverterPowerForecastChart < Base
      include Concerns::ForecastChart

      FORECAST_SENSOR_NAMES = %i[
        inverter_power
        inverter_power_forecast
        inverter_power_forecast_clearsky
      ].freeze
      public_constant :FORECAST_SENSOR_NAMES

      def unit
        return if chart_sensors.none?

        @unit ||=
          Sensor::UnitFormatter.format(
            unit: chart_sensors.first.unit,
            context: :rate, # Always show as rate (kW), not total (kWh)
          )
      end

      def actual_days
        forecast_data.size.clamp(1, 14)
      end

      private

      def forecast_sensor_name
        :inverter_power_forecast
      end

      def add_series_boundaries!(series_raw_data)
        Sensor::Forecast::BoundaryAdjuster.add_zero_boundaries!(series_raw_data)
      end

      def build_day_aggregation(date, entries)
        day_forecast = Sensor::Forecast::Day.new(date, entries)
        return unless day_forecast.valid?

        {
          noon_timestamp: day_forecast.noon_timestamp_ms,
          total_kwh: day_forecast.total_kwh,
        }
      end

      def label_builder
        @label_builder ||=
          Sensor::Forecast::LabelBuilder.new(
            forecast_data,
            today_analyzer,
            value_key: :total_kwh,
            unit: 'kWh',
            precision: 0,
          )
      end

      def style_for_sensor(sensor)
        case sensor.name
        when :inverter_power_forecast_clearsky
          {
            borderWidth: 1,
            borderDash: [2, 3],
            fill: false,
            backgroundColor: sensor.color_hex,
          }
        when :inverter_power
          # Actual power: solid line with fill
          super.merge(fill: true)
        else
          super
        end
      end
    end
  end
end
