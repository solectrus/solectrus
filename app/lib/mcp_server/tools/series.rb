module McpServer
  module Tools
    # Returns a time-ordered measurement series for one or more sensors, down to
    # sub-daily resolution (InfluxDB). This is what reveals intraday curves that
    # the daily-aggregated tools cannot show.
    class Series < Base
      # Hard cap on sensors per request. Each sensor is a separate InfluxDB
      # subquery yielding up to the point budget, so bound the per-request work
      # even though resolve_sensors already restricts to the configured set.
      MAX_SENSORS = 20
      private_constant :MAX_SENSORS

      tool_name 'get_series'
      title 'Get a time series for sensors'
      description <<~TEXT.strip
        Get a chronological measurement series for one or more sensors, down to
        sub-daily resolution. Use this for intraday curves and trends that the
        aggregated tools cannot show, e.g. "power consumption per hour
        yesterday", "battery SoC over the last week", "nightly base load",
        "heat pump compressor cycling", "charge/discharge curve today".

        This returns averaged value curves; for energy-accurate totals over a
        period (kWh, costs) use get_totals instead of integrating a
        coarse series here.

        The default aggregation "mean" matches the smoothed line curve shown in
        the SOLECTRUS UI exactly. "max"/"min" instead report the highest/lowest
        sample within each bucket, so they can surface short-lived spikes or dips
        that are averaged away in the UI curve and thus not visible there. Use
        "mean" for "what does the UI show", and "max" (ideally with a fine
        resolution) for a true instantaneous peak — and explain the difference
        when a peak deviates from the UI.

        Parameters:
          - sensors: names (from list_sensors), one or more.
          - timeframe: SOLECTRUS notation, e.g. "2026-06-21" (a day), "2026-W25"
            (a week), "2025-01-15..2025-02-12" (a range), "P24H" (last 24h).
          - resolution: "1m", "5m", "15m", "1h" or "1d". When omitted, the
            finest one that keeps the WHOLE response within
            #{Resolution::MAX_POINTS} points across all requested sensors — the
            budget is shared, so with N sensors each series gets
            #{Resolution::MAX_POINTS}/N points, not #{Resolution::MAX_POINTS} each.
            Exactly two things coarsen a request (explicit or default): that
            shared budget, and the forecast cadence — providers write at most
            one sample per 15 minutes, so forecast sensors alone are never
            answered finer than "15m". Nothing else does, so asking for a
            coarser resolution never yields a coarser result than asking for a
            finer one. Read back `resolution` (what was actually used),
            `coarsened` and — only when coarsened — `coarsened_reason`, which
            names the constraint and what you can change about it.
          - aggregation: "mean" (default, the value curve), "min" or "max" —
            applied per resolution bucket. There is deliberately no "sum":
            summing a coarse series is not an energy integration and reads as a
            misleading total. For period totals (Wh/kWh, costs) use get_totals,
            for the forecast use get_forecast.
          - include_nulls: true (default) returns the complete bucket grid,
            empty buckets included. Set it to false to get only the buckets that
            carry a value — worth doing for sensors that write sporadically
            rather than continuously (a device that only reports on load
            change), where the grid is mostly empty and the nulls dominate the
            response: a day at 5m is 288 points even when three of them have a
            value. The remaining points still sit on the same grid, so a gap
            between two consecutive timestamps means "no data" just as an
            explicit null does.

        Each series reports `point_count` alongside its `points`, so a
        truncated or unexpectedly coarse curve is visible without counting.

        Each point is {time, value}. `time` is the END of its bucket: at
        resolution "5m" the point labelled 07:05 covers 07:00–07:05, and the
        last point of a series carries the end of the requested timeframe. A
        value of null means "no data" (e.g. a sensor was offline) and is
        deliberately distinct from a measured 0.

        Buckets are cut on the installation's own timezone (reported by
        get_system_info), not on UTC: a "1d" bucket is a local calendar day,
        including the 23- or 25-hour day of a daylight-saving switch.
      TEXT
      input_schema(
        properties: {
          sensors: {
            type: 'array',
            items: {
              type: 'string',
            },
            description: 'Sensor names (from list_sensors).',
          },
          timeframe: {
            type: 'string',
            description:
              'SOLECTRUS timeframe with a span, e.g. "2026-06-21", "2026-W25", "2025-01-15..2025-02-12", "P24H".',
          },
          resolution: {
            type: 'string',
            enum: %w[1m 5m 15m 1h 1d],
            description: 'Bucket size. Defaults to the finest that fits the point limit.',
          },
          aggregation: {
            type: 'string',
            enum: %w[mean min max],
            description:
              'Per-bucket aggregation. Defaults to "mean". For period totals ' \
                '(Wh/kWh, costs) use get_totals, not a summed series.',
          },
          include_nulls: {
            type: 'boolean',
            description:
              'Keep empty buckets (default true). false omits them, which ' \
                'shrinks the response a lot for sporadically written sensors.',
          },
        },
        required: %w[sensors timeframe],
      )
      read_only idempotent: true

      def self.call(
        sensors:,
        timeframe:,
        resolution: nil,
        aggregation: 'mean',
        include_nulls: true,
        **
      )
        tf = Timeframe.new(timeframe)
        if tf.now?
          return error_response('Timeframe must cover a span, not the "now" instant.')
        end

        definitions = resolve_sensors(sensors)
        if definitions.size > MAX_SENSORS
          raise ArgumentError, "Too many sensors (max #{MAX_SENSORS})"
        end

        enforce_supported!(definitions, :series)

        agg = Aggregation.internal(aggregation)
        interval, label, coarsened_by = Resolution.for(resolution, tf, definitions)

        data =
          Sensor::Query::Series.new(
            definitions.map(&:name),
            tf,
            interval:,
            aggregation: agg,
            timestamp_method: :to_time,
          ).call

        json_response(
          timeframe: tf.to_s,
          resolution: label,
          coarsened: !coarsened_by.nil?,
          **Resolution.explain(coarsened_by, resolution, label, definitions.size),
          aggregation:,
          series:
            definitions.map { |sensor| series_for(sensor, data, agg, include_nulls:) },
        )
      rescue ArgumentError => e
        error_response(e.message)
      end

      def self.series_for(sensor, data, aggregation, include_nulls:)
        unit = mcp_unit(sensor)
        points = Points.build(data, sensor.name, aggregation, unit:, include_nulls:)

        {
          sensor: sensor.name,
          display_name: sensor.display_name,
          unit:,
          point_count: points.size,
          points:,
        }
      end
      private_class_method :series_for
    end
  end
end
