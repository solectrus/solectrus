module Sensor
  module Query
    # Fetches time series data for charts. The aggregation interval defaults
    # to 30s for the P1H (last hour) timeframe and 5m otherwise; callers can
    # override `interval:` to drive forecast, scatter and similar charts.
    class Series < Helpers::Influx::Base
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

      # Serialises the interval back into a Flux duration literal, e.g.
      # `5.minutes` becomes `"5m"`. Picks the largest unit that divides
      # cleanly so 3600 seconds renders as `1h`, not `60m` or `3600s`.
      def interval
        seconds = @interval.to_i
        return "#{seconds / 3600}h" if (seconds % 3600).zero?
        return "#{seconds / 60}m" if (seconds % 60).zero?

        "#{seconds}s"
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

        if other.any?
          definitions << other_stream(other)
          names << 'other'
        end

        # Reset the range on the union so every group shares the same
        # `_start`/`_stop` annotations - the cadence-shifted forecast samples
        # would otherwise pull `_start` earlier than the live streams. With
        # aligned bounds, `aggregateWindow` emits the same bucket grid
        # (including null-filled empty buckets, by default) for every sensor,
        # which keeps Chart.js index-mode tooltips paired at the correct
        # timestamp.
        input = names.one? ? names.first : "union(tables: [#{names.join(', ')}])"
        range_reset = "|> range(start: #{@timeframe.beginning.iso8601}, stop: #{@timeframe.ending.iso8601})"
        prefix = interpolate ? ['import "interpolate"'] : []
        [*prefix, *definitions, input, range_reset, *aggregation_tail(fill_zero:)].join("\n")
      end

      def base_pipeline(sensors: available_sensors, lookback: 0)
        <<~FLUX.chomp
          #{from_bucket}
          |> #{range(start: @timeframe.beginning - lookback, stop: @timeframe.ending)}
          |> #{filter(selected_sensors: sensors)}
        FLUX
      end

      # Emits a per-measurement Flux block of the shape:
      #
      #   fc_N_raw       = <bucket+filter pipeline>
      #   fc_N_rec       = (fc_N_raw |> elapsed |> median |> findRecord)
      #   fc_N_shift_ns  = if exists fc_N_rec.elapsed then ... else 0
      #   [fc_N_interp   = fc_N_raw |> densify(every: interval)]
      #   fc_N           = <source> |> timeShift(duration: -shift_ns/2)
      #
      # `if exists` guards against empty forecast data: findRecord on an
      # empty table returns a record without `elapsed`, and `int(v: invalid)`
      # would fail the whole query. The cadence is derived from the raw
      # samples (before optional interpolation) so a densified Solcast 30m
      # stream still yields a 30m median - the basis for the -cadence/2
      # shift. Aggregation happens on the unioned output so the resulting
      # bucket grid spans the cadence-shifted samples and stays aligned
      # across forecast and live streams.
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

      def aggregation_tail(fill_zero:, fill_previous: false)
        # `last` pairs with fill_previous: carrying a value forward is only
        # coherent if each bucket holds the most recent sample, not a mean.
        # aggregateWindow's default createEmpty: true emits null buckets
        # across the window range; this also covers the selector path so
        # mixed forecast/live streams share a common x-axis grid (Chart.js
        # index-mode tooltips need that to pair values correctly).
        fn = fill_previous ? 'last' : 'mean'
        tail = ["|> aggregateWindow(every: #{interval}, fn: #{fn})"]
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
        # Memoise per raw `_time` string: each timestamp typically appears
        # once per sensor in the union, so this halves Time.zone.parse calls
        # in the mixed forecast/other path.
        time_cache = {}

        flux_result.each do |table|
          table.records.each do |record|
            values = record.values
            # Skip rows whose measurement/field don't map to a configured
            # sensor (e.g. stray fields shared in the same Influx series).
            sensor = find_sensor_by_measurement_and_field(values['_measurement'], values['_field'])
            next unless sensor

            time_key = time_cache[record.time] ||=
              Time.zone.parse(record.time).public_send(@timestamp_method)
            result[[sensor, :avg, :avg]][time_key] = values['_value']&.round(1)
          end
        end

        result
      end
    end
  end
end
