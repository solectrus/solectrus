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
        Chronological measurement series for one or more sensors, down to
        sub-daily resolution — the intraday curves the aggregated tools cannot
        show ("consumption per hour yesterday", "battery SoC over the last
        week", "nightly base load"). These are averaged value curves; for
        energy-accurate period totals (kWh, costs) use get_totals, not an
        integration of a coarse series here.

        Aggregation, per bucket: "mean" (default) is the curve the SOLECTRUS UI
        shows. "max"/"min" report the extreme sample in a bucket and so surface
        short-lived spikes the mean hides — use "max" with a fine resolution for
        a true instantaneous peak. There is deliberately no "sum": summing a
        coarse series is not an energy integration.

        Resolution: when omitted, the finest that keeps the WHOLE response
        within #{Resolution::MAX_POINTS} points — the budget is SHARED, so N
        sensors get #{Resolution::MAX_POINTS}/N points each. Exactly two things
        coarsen a request: that budget, and the forecast cadence (providers
        write at most one sample per 15 min, so forecast sensors alone are never
        answered finer than "15m"). Nothing else, so a coarser request never
        yields a coarser result than a finer one. Read back `resolution`,
        `coarsened`, and `coarsened_reason` (only when coarsened) — it names the
        constraint and what to change.

        include_nulls (default true) returns the complete bucket grid. false
        drops the empty buckets, which pays off for sporadically written sensors
        where a day at 5m is 288 points carrying three values; the rest stay on
        the same grid, so a gap reads exactly like an explicit null.

        Each point is {time, value}, and `time` is the END of its bucket: at
        "5m" the point 07:05 covers 07:00–07:05, and the last point carries the
        end of the requested timeframe. null means "no data", deliberately
        distinct from a measured 0. Each series also reports `point_count`.

        Buckets are cut on the installation's timezone (see get_system_info),
        not UTC: a "1d" bucket is a local calendar day, including the 23- or
        25-hour day of a daylight-saving switch.

        A timeframe that cannot hold measured data — entirely in the future, or
        ending before the installation date — carries a `timeframe_note`, so an
        all-null curve is never mistaken for an outage. A forecast sensor over a
        future timeframe is normal and gets none.
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
          timeframe: timeframe_property('The period the curve covers.'),
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
        tf = parse_timeframe(timeframe)
        if tf.now?
          return error_response('Timeframe must cover a span, not the "now" instant.')
        end

        definitions, unknown = resolve_sensors(sensors)
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
          **measured_timeframe_note(definitions, tf),
          **unknown_sensors_note(unknown),
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

      # A timeframe in the future is the whole point of a forecast sensor, so
      # the "nothing measured yet" note only applies without one.
      def self.measured_timeframe_note(definitions, timeframe)
        return {} if definitions.any?(&:forecast?)

        timeframe_note(timeframe)
      end
      private_class_method :measured_timeframe_note

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
