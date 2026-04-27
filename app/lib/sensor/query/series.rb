module Sensor
  module Query
    # Fetches time series data with dynamic aggregation intervals:
    # - 30-second intervals for 'now' timeframe
    # - 5-minute intervals for all other timeframes
    # Used for: Charts and data visualization
    class Series < Helpers::Influx::Base
      INTERVAL_UNITS = { 1 => 's', 60 => 'm', 3600 => 'h' }.freeze
      private_constant :INTERVAL_UNITS

      def initialize(
        sensor_names,
        timeframe,
        timestamp_method: nil,
        interval: nil
      )
        super(sensor_names, timeframe)

        @timestamp_method =
          timestamp_method || (timeframe.short? ? :to_time : :to_date)
        @interval = interval || (timeframe.p1h? ? 30.seconds : 5.minutes)
      end

      def interval
        seconds = @interval.to_i
        unit_size = INTERVAL_UNITS.keys.rfind { |s| (seconds % s).zero? }
        "#{seconds / unit_size}#{INTERVAL_UNITS[unit_size]}"
      end

      def call(interpolate: false, fill_zero: false, fill_previous: false)
        raise ArgumentError, 'fill_previous excludes fill_zero/interpolate' if fill_previous && (fill_zero || interpolate)
        return empty_result if available_sensors.empty?
        return empty_result if @timeframe.now?

        raw_data = fetch_aggregated_series(interpolate:, fill_zero:, fill_previous:)

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
        forecast, other = available_sensors.partition { |name| Sensor::Registry[name]&.forecast? }

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
        pipeline = base_pipeline(lookback: fill_previous ? 2.hours : 0)
        pipeline = densify(pipeline) if interpolate

        prefix = interpolate ? ['import "interpolate"'] : []
        [*prefix, pipeline, *aggregation_tail(fill_zero:, fill_previous:)].join("\n")
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
        names = Array.new(groups.size) { |i| "fc_#{i}" }
        tail = aggregation_tail(fill_zero:)

        # Mid-window stamping is only meaningful when forecast samples must
        # be visually compared against denser-aggregated charts: that's
        # exactly the mixed forecast/non-forecast scenario. A pure-forecast
        # query keeps its right-edge stamp to stay consistent with how
        # forecast providers timestamp their own samples.
        if other.any?
          definitions << other_stream(other)
          names << 'other'
          tail.insert(1, "|> timeShift(duration: -#{half_interval_seconds}s)")
        end

        input = names.one? ? names.first : "union(tables: [#{names.join(', ')}])"
        prefix = interpolate ? ['import "interpolate"'] : []
        [*prefix, *definitions, input, *tail].join("\n")
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
        parts << "#{name}_interp = #{densify("#{name}_raw")}" if interpolate
        parts << "#{name} = #{source} |> timeShift(duration: duration(v: #{name}_shift_ns / -2))"
        parts.join("\n")
      end

      def other_stream(other)
        "other = #{base_pipeline(sensors: other)}"
      end

      def densify(stream_expr)
        <<~FLUX.chomp
          #{stream_expr}
            |> map(fn:(r) => ({ r with _value: float(v: r._value) }))
            |> interpolate.linear(every: #{interval})
        FLUX
      end

      def half_interval_seconds
        @interval.to_i / 2
      end

      def aggregation_tail(fill_zero:, fill_previous: false)
        # `last` pairs with fill_previous: carrying a value forward is only
        # coherent if each bucket holds the most recent sample, not a mean.
        tail = ["|> aggregateWindow(every: #{interval}, fn: #{fill_previous ? 'last' : 'mean'})"]
        tail << '|> fill(column: "_value", usePrevious: true)' if fill_previous
        tail << '|> fill(value: 0.0)' if fill_zero
        tail << "|> filter(fn: (r) => r._time >= #{@timeframe.beginning.iso8601})" if fill_previous
        tail << '|> keep(columns: ["_time","_field","_measurement","_value"])'
        tail
      end

      # Folds Flux records directly into the result shape consumed by
      # Sensor::Data::Series (`{[sensor, :avg, :avg] => {time_key => value}}`).
      # `:avg` reflects the aggregateWindow(fn: mean) used upstream. Empty
      # buckets keep their `_value = null` so Chart.js renders real data
      # gaps as visible breaks instead of bridging them.
      def parse_series_result(flux_result)
        result = Hash.new { |h, k| h[k] = {} }
        sensor_cache = {}
        time_cache = {}

        flux_result.each do |table|
          table.records.each do |record|
            values = record.values
            key = [values['_measurement'], values['_field']]
            sensor = (sensor_cache[key] ||= find_sensor_by_measurement_and_field(*key))
            next unless sensor

            time_key = (time_cache[record.time] ||= Time.zone.parse(record.time).public_send(@timestamp_method))
            result[[sensor, :avg, :avg]][time_key] = values['_value']&.round(1)
          end
        end

        result
      end
    end
  end
end
