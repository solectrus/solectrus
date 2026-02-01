module Sensor
  module Chart
    class OutdoorTempForecast < Base # rubocop:disable Metrics/ClassLength
      include Concerns::Forecast

      FORECAST_SENSOR_NAMES = %i[outdoor_temp outdoor_temp_forecast].freeze
      public_constant :FORECAST_SENSOR_NAMES

      # Ensure visible bars when min == max; base fallback epsilon in Grad Celsius.
      BAR_RANGE_EPSILON = 0.4
      public_constant :BAR_RANGE_EPSILON

      # Use a small fraction of overall temperature range as epsilon.
      BAR_RANGE_RATIO = 0.02
      public_constant :BAR_RANGE_RATIO

      # Minimum epsilon derived from range to avoid vanishing bars.
      MIN_BAR_RANGE_EPSILON = 0.2
      public_constant :MIN_BAR_RANGE_EPSILON

      def type
        'bar'
      end

      private

      def crosshair_options
        {}
      end

      def zoom_options
        {
          zoom: {
            drag: {
              enabled: true,
            },
            mode: 'x',
          },
        }
      end

      def tooltip_options
        super.merge(
          position: 'fixedBottom',
          yAlign: 'top',
        )
      end

      def build_data
        return if forecast_data.blank?

        sensor = Sensor::Registry[:outdoor_temp_forecast]

        labels, range_data, avg_data, min_data, max_data =
          build_day_data(sensor)

        return if range_data.compact.empty? && avg_data.compact.empty?

        datasets =
          build_datasets(
            sensor,
            range_data:,
            min_data:,
            max_data:,
            avg_data:,
          )

        { labels:, datasets: }
      end

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

      def build_day_data(sensor)
        rows =
          forecast_data
            .sort_by { |date, _| date }
            .map do |_, data|
              min_val, max_val, avg_val =
                data.values_at(:min_temp, :max_temp, :avg_temp).tap do |values|
                  values.map! { |value| clamp_value(sensor, value) }
                end
              [data[:noon_timestamp], min_val, max_val, avg_val]
            end

        labels, min_data, max_data, avg_data = rows.transpose

        range_data = build_range_data(min_data, max_data)

        [labels, range_data, avg_data, min_data, max_data]
      end

      def clamp_value(sensor, value)
        value ? sensor.clamp_value(value) : nil
      end

      def build_range_data(min_data, max_data)
        overall_min = min_data.compact.min
        overall_max = max_data.compact.max
        range_epsilon = calculate_range_epsilon(overall_min, overall_max)

        min_data.zip(max_data).tap do |range_data|
          range_data.map! do |min_val, max_val|
            build_range_entry(
              min_val,
              max_val,
              range_epsilon,
              overall_max,
            )
          end
        end
      end

      def calculate_range_epsilon(min_val, max_val)
        return BAR_RANGE_EPSILON unless min_val && max_val

        range = max_val - min_val
        range.positive? ? [range * BAR_RANGE_RATIO, MIN_BAR_RANGE_EPSILON].max : BAR_RANGE_EPSILON
      end

      def build_range_entry(min_val, max_val, epsilon, overall_max)
        return unless min_val && max_val
        return [min_val, max_val] unless min_val == max_val

        # Ensure a visible bar when min == max by adding a tiny offset
        return [min_val - epsilon, max_val] if overall_max && max_val >= overall_max - epsilon

        [min_val, max_val + epsilon]
      end

      def build_datasets(sensor, range_data:, min_data:, max_data:, avg_data:)
        datasets = [build_range_dataset(sensor, range_data)]
        high_res_curve = build_high_res_curve_dataset(sensor)
        datasets << high_res_curve if high_res_curve
        point_style = {
          pointStyle: 'circle',
          pointRadius: 6,
          pointHoverRadius: 6,
          pointBorderWidth: 2,
          pointHoverBorderWidth: 2,
          order: 2,
        }
        [[:min, min_data], [:max, max_data]].each do |suffix, data|
          next if data.compact.none?

          datasets << build_point_dataset(
            sensor,
            data,
            id: "#{sensor.name}_#{suffix}",
            style: point_style,
          )
        end
        if avg_data.compact.any?
          datasets << build_point_dataset(
            sensor,
            avg_data,
            id: "#{sensor.name}_avg",
            label: I18n.t('forecast.average'),
            style: {
              pointStyle: 'line',
              pointRadius: 8,
              pointHoverRadius: 9,
              pointBorderWidth: 4,
              pointHoverBorderWidth: 4,
              fill: false,
              tension: 0,
              order: 3,
            },
          )
        end
        datasets
      end

      def build_high_res_curve_dataset(sensor)
        points = build_high_res_curve_points
        return if points.blank?

        {
          id: "#{sensor.name}_curve_high_res",
          label: sensor.display_name,
          data: points,
          type: 'line',
          showLine: true,
          fill: false,
          tension: 0.4,
          borderWidth: 3,
          pointRadius: 0,
          pointHitRadius: 6,
          pointHoverRadius: 0,
          colorScale: sensor.color_scale,
          opacity: 0.35,
          order: 0,
        }
      end

      def build_high_res_curve_points
        forecast_points = extract_sensor_data(:outdoor_temp_forecast)
        actual_points = extract_sensor_data(:outdoor_temp)
        return if forecast_points.blank? && actual_points.blank?

        now = Time.current
        points = []

        append_curve_points(points, actual_points) do |time|
          time.to_date == Date.current && time <= now
        end

        append_curve_points(points, forecast_points) do |time|
          time.to_date != Date.current || time > now
        end

        points.sort_by { |point| point[:x] }
      end

      def append_curve_points(points, source)
        return if source.blank?

        source.each do |timestamp, value|
          next if value.nil?

          time = normalize_timestamp(timestamp)
          next unless yield(time)

          points << {
            x: timestamp_to_ms(time),
            y: value,
          }
        end
      end

      def build_range_dataset(sensor, range_data)
        {
          id: sensor.name.to_s,
          label: sensor.display_name,
          tooltip: false,
          data: range_data,
          barThickness: 6,
          maxBarThickness: 8,
          order: 1,
        }.merge(style_for_sensor(sensor)).merge(
          borderWidth: 0,
          colorScale: sensor.color_scale,
        )
      end

      def build_point_dataset(sensor, data, id:, label: '', style: {})
        {
          id: id,
          label: label,
          tooltip: false,
          data: data,
          type: 'line',
          showLine: false,
          borderWidth: 0,
          colorScale: sensor.color_scale,
          noGradient: true,
        }.merge(style)
      end

      def label_builder
        @label_builder ||=
          Sensor::Forecast::LabelBuilder.new(
            forecast_data,
            today_analyzer,
            value_key: :avg_temp,
          )
      end
    end
  end
end
