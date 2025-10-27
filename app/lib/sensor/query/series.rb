module Sensor
  module Query
    # Fetches time series data with dynamic aggregation intervals:
    # - 30-second intervals for 'now' timeframe
    # - 5-minute intervals for all other timeframes
    # Used for: Charts and data visualization
    class Series < Helpers::Influx::Base
      def call(interpolate: false)
        return empty_result if available_sensors.empty?
        return empty_result if @timeframe.now? # No series for current moment

        # Charts use mean aggregation with dynamic intervals
        raw_data = fetch_aggregated_series(interpolate:)

        # Use parent's create_data_instance and process_calculated_sensors
        create_data_instance(raw_data, @timeframe).tap do |data|
          ensure_sensor_accessors(data)
          process_calculated_sensors(data)
        end
      end

      protected

      def create_data_instance(raw_data, timeframe)
        Sensor::Data::Series.new(raw_data, timeframe:)
      end

      private

      def fetch_aggregated_series(interpolate: false)
        query_string = build_series_flux_query(interpolate:)
        result = query(query_string)
        parse_series_result(result)
      end

      def build_series_flux_query(interpolate: false)
        q = []
        q << 'import "interpolate"' if interpolate
        q << from_bucket
        q << "|> #{range(start: @timeframe.beginning, stop: @timeframe.ending)}"
        q << "|> #{filter}"

        if interpolate
          q << '|> map(fn:(r) => ({ r with _value: float(v: r._value) }))'
          q << "|> interpolate.linear(every: #{interval})"
        else
          q << '|> aggregateWindow(every: 5s, fn: last)'
          q << '|> fill(usePrevious: true)'
        end
        q << "|> aggregateWindow(every: #{interval}, fn: mean)"
        q << '|> keep(columns: ["_time","_field","_measurement","_value"])'

        q.join("\n")
      end

      def interval
        timeframe.p1h? ? '30s' : '5m'
      end

      def parse_series_result(flux_result)
        points_by_timestamp = group_records_by_timestamp(flux_result)
        convert_to_series_format(points_by_timestamp)
      end

      def group_records_by_timestamp(flux_result)
        points_by_timestamp = {}
        sensor_cache = {} # Memoize sensor lookups to avoid repeated calls

        flux_result.each do |table|
          table.records.each do |record|
            process_record_optimized(record, points_by_timestamp, sensor_cache)
          end
        end

        points_by_timestamp
      end

      def process_record_optimized(record, points_by_timestamp, sensor_cache)
        # Cache record.values to avoid repeated hash access
        record_values = record.values

        value = record_values['_value']
        return unless value

        measurement = record_values['_measurement']
        field = record_values['_field']
        timestamp = Time.zone.parse(record.time)

        # Memoized sensor lookup - avoid repeated find_sensor calls
        sensor_key = "#{measurement}:#{field}"
        sensor =
          sensor_cache[sensor_key] ||= find_sensor_by_measurement_and_field(
            measurement,
            field,
          )

        return unless sensor

        # Initialize point if not exists - timestamp is already a Time object
        points_by_timestamp[timestamp] ||= { timestamp: }
        points_by_timestamp[timestamp][sensor] = value.round(1)
      end

      def convert_to_series_format(points_by_timestamp)
        result = {}
        all_sensors = collect_all_sensors(points_by_timestamp)

        all_sensors.each do |sensor|
          time_series =
            build_time_series_for_sensor(sensor, points_by_timestamp)
          add_sensor_data_to_result(result, sensor, time_series)
        end

        result
      end

      def collect_all_sensors(points_by_timestamp)
        all_sensors = []
        points_by_timestamp.each_value do |point|
          point.each_key { |key| all_sensors << key if key != :timestamp }
        end
        all_sensors.uniq
      end

      def build_time_series_for_sensor(sensor, points_by_timestamp)
        time_series = {}

        points_by_timestamp.each do |timestamp, point|
          time_key = determine_time_key(timestamp)
          time_series[time_key] = point[sensor]
        end
        time_series
      end

      def determine_time_key(timestamp)
        @timeframe.short? ? timestamp : timestamp.to_date
      end

      def add_sensor_data_to_result(result, sensor, time_series)
        return if time_series.empty?

        # Use the format expected by new Series: [sensor, :avg, :avg]
        # For InfluxDB series data, we use :avg since we aggregate with mean
        result[[sensor, :avg, :avg]] = time_series
      end
    end
  end
end
