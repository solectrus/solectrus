module Sensor
  module Chart
    module Concerns
      module Forecast # rubocop:disable Metrics/ModuleLength
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
              autoPadding: false,
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
            min: timeframe.beginning.beginning_of_day,
            max: timeframe.ending.to_date.tomorrow.beginning_of_day,
            bounds: 'data',
            grid: {
              drawOnChartArea: false,
              drawTicks: false,
            },
            offset: false,
            ticks: {
              maxRotation: 0,
              autoSkip: false,
              display: false,
            },
          )
        end

        def y_scale_options
          return super unless forecast_sensor_data

          super.merge(fixedWidth: 50)
        end

        def x_axis_labels
          @x_axis_labels ||= label_builder.build_labels
        end

        def forecast_data
          @forecast_data ||= build_forecast_data
        end

        def forecast_sensor_data
          @forecast_sensor_data ||= extract_sensor_data(forecast_sensor_name)
        end

        def today_analyzer
          @today_analyzer ||=
            Sensor::Forecast::TodayAnalyzer.new(forecast_sensor_data)
        end

        # Extract sensor data by sensor name
        def extract_sensor_data(sensor_name)
          return unless series&.raw_data

          series.raw_data.find { |key, _| key.first == sensor_name }&.last
        end

        # Build forecast data from sensor data
        def build_forecast_data
          return {} unless forecast_sensor_data

          grouped_by_date =
            forecast_sensor_data.group_by do |timestamp, _|
              timestamp.to_date
            end

          filtered_entries =
            grouped_by_date.filter_map do |date, entries|
              build_forecast_entry(date, entries)
            end

          raw_forecast_data =
            filtered_entries
              .reject { |date, _| exclude_today?(date) }
              .to_h

          # Pad with empty days if needed to match timeframe
          pad_forecast_data_to_timeframe(raw_forecast_data)
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

        # Pad forecast data with empty days to match timeframe
        def pad_forecast_data_to_timeframe(data)
          # Determine date range from timeframe
          start_date = data.keys.min || timeframe.beginning.to_date
          end_date = timeframe.ending.to_date

          # Fill all days in range
          (start_date..end_date).index_with do |date|
            if data.key?(date)
              data[date]
            else
              # Create empty placeholder with noon timestamp for consistent X-axis
              noon_time = date.in_time_zone.change(hour: NOON_HOUR)
              { noon_timestamp: noon_time.to_i * MS_PER_SECOND }
            end
          end
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
