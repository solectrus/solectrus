module Sensor
  module Query
    # Fetches time series data with dynamic aggregation intervals:
    # - 30-second intervals for 'now' timeframe
    # - 5-minute intervals for all other timeframes
    # Used for: Charts and data visualization
    class Series < Helpers::Influx::Base # rubocop:disable Metrics/ClassLength
      def initialize(
        sensor_names,
        timeframe,
        timestamp_method: nil,
        interval: nil
      )
        super(sensor_names, timeframe)

        @timestamp_method =
          timestamp_method || (timeframe.short? ? :to_time : :to_date)
        @interval = interval || (timeframe.p1h? ? '30s' : '5m')
      end

      attr_reader :interval

      def call(interpolate: false, fill_zero: false, fill_previous: false)
        raise ArgumentError, 'fill_previous excludes fill_zero/interpolate' if fill_previous && (fill_zero || interpolate)
        return empty_result if available_sensors.empty?
        return empty_result if @timeframe.now? # No series for current moment

        # Charts use mean aggregation with dynamic intervals
        raw_data = fetch_aggregated_series(interpolate:, fill_zero:, fill_previous:)

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

      def fetch_aggregated_series(interpolate: false, fill_zero: false, fill_previous: false)
        query_string = build_series_flux_query(interpolate:, fill_zero:, fill_previous:)
        result = query(query_string)
        parse_series_result(result)
      end

      def build_series_flux_query(interpolate: false, fill_zero: false, fill_previous: false)
        forecast, other = available_sensors.partition { |name| Sensor::Registry[name]&.category == :forecast }

        # plain-query is fine when there is no forecast at all, or when only
        # forecast samples are queried with interpolation: provider samples
        # already sit on the requested grid, so neither alignment with a
        # dense sensor nor a cadence-shift is needed.
        if forecast.empty? || (interpolate && other.empty?)
          build_plain_query(interpolate:, fill_zero:, fill_previous:)
        else
          build_forecast_shifted_query(forecast, other, interpolate:, fill_zero:)
        end
      end

      def build_plain_query(interpolate:, fill_zero:, fill_previous: false)
        # 2h lookback caps forward-fill staleness: beyond it, gaps stay visible.
        q = [base_pipeline(lookback: fill_previous ? 2.hours : 0)]

        if interpolate
          q.unshift('import "interpolate"')
          q << '|> map(fn:(r) => ({ r with _value: float(v: r._value) }))'
          q << "|> interpolate.linear(every: #{interval})"
        end

        (q + aggregation_tail(fill_zero:, fill_previous:)).join("\n")
      end

      # Forecast providers store each sample at the end of its aggregation
      # window (PVNode 15m, Solcast 30m, forecast.solar 60m). Without a shift
      # they lag other sensors by half a window. Forecast sensors are grouped
      # by measurement (= same provider = same cadence), and per group we
      # derive the cadence from the median gap between consecutive samples
      # and apply a timeShift of -cadence/2 - preserving every sample
      # including the sunrise/sunset 0-boundaries that sparse providers emit
      # at irregular offsets outside the normal cadence. Per-measurement
      # grouping is required because providers with different cadences may
      # be mixed (e.g. a 15m power forecast next to a 60m temperature
      # forecast), while multiple fields from the same provider share one
      # scan. When `interpolate:` is set, forecast streams are densified to
      # `interval` before the shift so sparse providers (Solcast 30m,
      # forecast.solar 60m) render without gaps; non-forecast streams stay
      # un-interpolated so aggregateWindow yields true window means rather
      # than instant samples picked at bucket edges.
      def build_forecast_shifted_query(forecast, other, interpolate:, fill_zero:)
        groups = forecast.group_by { |name| Sensor::Config.measurement(name) }.values
        definitions = groups.each_with_index.map { |sensors, i| forecast_stream(sensors, i, interpolate:) }
        definitions << other_stream(other) if other.any?

        names = Array.new(groups.size) { |i| "fc_#{i}" }
        names << 'other' if other.any?
        input = names.one? ? names.first : "union(tables: [#{names.join(', ')}])"

        # Mid-window stamping is only meaningful when forecast samples must
        # be visually compared against denser-aggregated charts: that's
        # exactly the mixed forecast/non-forecast scenario. A pure-forecast
        # query (no `other`) keeps its right-edge stamp to stay consistent
        # with how forecast providers timestamp their own samples.
        mid_window = other.any?
        prefix = interpolate ? ['import "interpolate"'] : []
        [*prefix, *definitions, input, *aggregation_tail(fill_zero:, mid_window:)].join("\n")
      end

      def base_pipeline(sensors: available_sensors, lookback: 0)
        <<~FLUX.chomp
          #{from_bucket}
          |> #{range(start: @timeframe.beginning - lookback, stop: @timeframe.ending)}
          |> #{filter(selected_sensors: sensors)}
        FLUX
      end

      # `if exists` guards against empty forecast data: findRecord on an
      # empty table returns a record without `elapsed`, and `int(v: invalid)`
      # would fail the whole query. The cadence is derived from the raw
      # samples (before optional interpolation) so a densified Solcast 30m
      # stream still yields a 30m median - the basis for the -cadence/2
      # shift.
      def forecast_stream(sensors, index, interpolate: false)
        name = "fc_#{index}"
        source = interpolate ? "#{name}_interp" : "#{name}_raw"

        parts = [
          "#{name}_raw = #{base_pipeline(sensors:)}",
          <<~FLUX.chomp,
            #{name}_rec = (#{name}_raw
              |> elapsed(unit: 1ns)
              |> median(column: "elapsed")
              |> findRecord(fn: (key) => true, idx: 0))
            #{name}_shift_ns = if exists #{name}_rec.elapsed then int(v: #{name}_rec.elapsed) else 0
          FLUX
        ]

        if interpolate
          parts << <<~FLUX.chomp
            #{name}_interp = #{name}_raw
              |> map(fn:(r) => ({ r with _value: float(v: r._value) }))
              |> interpolate.linear(every: #{interval})
          FLUX
        end

        parts << "#{name} = #{source} |> timeShift(duration: duration(v: #{name}_shift_ns / -2))"
        parts.join("\n")
      end

      def other_stream(other)
        "other = #{base_pipeline(sensors: other)}"
      end

      INTERVAL_UNIT_SECONDS = { 's' => 1, 'm' => 60, 'h' => 3600 }.freeze
      private_constant :INTERVAL_UNIT_SECONDS

      def half_interval_seconds
        num = Integer(interval[/\d+/])
        unit = interval[/[a-z]+/]
        (num * INTERVAL_UNIT_SECONDS[unit]) / 2
      end

      def aggregation_tail(fill_zero:, fill_previous: false, mid_window: false)
        # `last` pairs with fill_previous: carrying a value forward is only
        # coherent if each bucket holds the most recent sample, not a mean.
        tail = ["|> aggregateWindow(every: #{interval}, fn: #{fill_previous ? 'last' : 'mean'})"]
        # Re-anchor each bucket on its midpoint instead of its right edge.
        # Without this a 15-min mean stamped at the bucket end visually
        # leads the actual reading by half a window when compared against
        # finer-grained charts (e.g. the 5-min day chart). With mid-window
        # the point sits where the data is centred, so a 5-min sample at
        # the same x reads close to the 15-min mean.
        tail << "|> timeShift(duration: -#{half_interval_seconds}s)" if mid_window
        tail << '|> fill(column: "_value", usePrevious: true)' if fill_previous
        tail << '|> fill(value: 0.0)' if fill_zero
        tail << "|> filter(fn: (r) => r._time >= #{@timeframe.beginning.iso8601})" if fill_previous
        tail << '|> keep(columns: ["_time","_field","_measurement","_value"])'
        tail
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

        # aggregateWindow emits empty windows with _value = null by default
        # (createEmpty: true). Keep them as nil instead of filtering them
        # out so Chart.js renders real data gaps as visible breaks.
        points_by_timestamp[timestamp] ||= { timestamp: }
        points_by_timestamp[timestamp][sensor] = record_values['_value']&.round(1)
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
        all_sensors = Set.new
        points_by_timestamp.each_value do |point|
          point.each_key { |key| all_sensors << key if key != :timestamp }
        end
        all_sensors.to_a
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
        timestamp.public_send(@timestamp_method)
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
