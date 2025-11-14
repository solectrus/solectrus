module Sensor
  module Chart
    module Concerns
      module ForecastChart # rubocop:disable Metrics/ModuleLength
        extend ActiveSupport::Concern

        BOUNDARY_INTERVAL = 15.minutes
        NOON_HOUR = 12
        MS_PER_SECOND = 1000

        public_constant :BOUNDARY_INTERVAL, :NOON_HOUR, :MS_PER_SECOND

        def type
          'line'
        end

        def use_sql_for_timeframe?
          false # Always use InfluxDB for forecast data
        end

        def options
          return super unless forecast_sensor_data

          super.merge(
            interaction: {
              intersect: false,
              mode: 'index',
            },
            layout: {
              padding: {
                bottom: 80,
              },
            }, # Extra space for custom x-axis labels
            plugins:
              super[:plugins].merge(
                customXAxisLabels: {
                  enabled: true,
                  labels: x_axis_labels,
                },
              ),
          )
        end

        def chart_sensor_names
          Sensor::Config.sensors.filter_map do |sensor|
            sensor.name if sensor.name.in?(self.class::FORECAST_SENSOR_NAMES)
          end
        end

        def unit
          return if chart_sensors.none?

          @unit ||= Sensor::UnitFormatter.format(unit: chart_sensors.first.unit)
        end

        private

        def build_influx_series
          Sensor::Query::Series
            .new(
              chart_sensor_names,
              timeframe,
              timestamp_method: :to_time,
              interval: '15m',
            )
            .call(interpolate: true)
            &.tap { |result| add_series_boundaries!(result.raw_data) }
        end

        def x_time_options
          { tooltipFormat: 'cccc, HH:mm', unit: 'day' }
        end

        def x_scale_options
          return super unless forecast_sensor_data

          super.merge(
            min: timestamp_to_ms(x_timestamps.min),
            max: timestamp_to_ms(x_timestamps.max),
            grid: {
              drawOnChartArea: false,
              drawTicks: false,
            },
            ticks: {
              maxRotation: 0,
              autoSkip: false,
              display: false,
            },
          )
        end

        def x_axis_labels
          @x_axis_labels ||= label_builder.build_labels
        end

        def forecast_data
          @forecast_data ||= build_forecast_data
        end

        def x_timestamps
          @x_timestamps ||= extract_timestamps
        end

        def forecast_sensor_data
          @forecast_sensor_data ||= extract_sensor_data(forecast_sensor_name)
        end

        def today_analyzer
          @today_analyzer ||= Sensor::Forecast::TodayAnalyzer.new(forecast_sensor_data)
        end

        def timestamp_to_ms(timestamp)
          timestamp&.to_i&.*(MS_PER_SECOND)
        end

        # Extract sensor data by sensor name
        def extract_sensor_data(sensor_name)
          return unless series&.raw_data

          series.raw_data.find { |key, _| key.first == sensor_name }&.last
        end

        # Extract all unique timestamps from series data
        def extract_timestamps
          series.raw_data.values.flat_map { |data| data.map(&:first) }.compact
        end

        # Build forecast data from sensor data
        def build_forecast_data
          return {} unless forecast_sensor_data

          forecast_sensor_data
            .group_by { |timestamp, _| timestamp.to_date }
            .filter_map { |date, entries| build_forecast_entry(date, entries) }
            .reject { |date, _| exclude_today?(date) }
            .to_h
        end

        def build_forecast_entry(date, entries)
          return if entries.empty?

          aggregation_data = build_day_aggregation(date, entries)
          return unless aggregation_data

          [date, aggregation_data]
        end

        def exclude_today?(date)
          date == Date.current && !today_analyzer.show_today?
        end

        # Template methods: Subclasses must implement
        def forecast_sensor_name
          raise NotImplementedError,
                "#{self.class} must implement #forecast_sensor_name"
        end

        def build_day_aggregation(_date, _entries)
          raise NotImplementedError,
                "#{self.class} must implement #build_day_aggregation"
        end

        # Template method: Subclasses can override
        def add_series_boundaries!(_series_raw_data)
          # Default: no boundary adjustment
        end
      end
    end
  end
end
