module McpServer
  module Tools
    # Returns a time-ordered measurement series for one or more sensors, down to
    # sub-daily resolution (InfluxDB). This is what reveals intraday curves that
    # the daily-aggregated tools cannot show.
    class Series < Base
      tool_name 'get_series'
      title 'Get a time series for sensors'
      description <<~TEXT.strip
        Chronological measurement series for one or more sensors, down to
        sub-daily resolution — the intraday curves the aggregated tools cannot
        show ("consumption per hour yesterday", "battery SoC over the last
        week", "nightly base load"). These are averaged value curves; for
        energy-accurate period totals (kWh, costs) use get_totals, not an
        integration of a coarse series here.

        A bucket's value is the unweighted mean of its samples, not a
        time-weighted one, so it drifts from the energy-weighted figure the
        summaries hold — the wider the bucket, the more, and UPWARD for a
        sensor written on change: its idle minutes carry no samples, so a
        coarse curve can integrate to a multiple of what get_totals reports.
        That reaches the averaged ratios too (autarky, self-consumption
        rate), derived here from the bucket's mean powers: at "1d" they can read
        a few tenths of a point beside get_totals and get_ranking, which are the
        period-accurate answer.

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
        the same grid, so a gap reads exactly like an explicit null. It also
        buys resolution on the RUNNING period: buckets still ahead cannot carry
        a point, so they do not count against the budget.

        Each point is {time, value}, and `time` is the END of its bucket: at
        "5m" the point 07:05 covers 07:00–07:05, and the last point carries the
        end of the requested timeframe — a day ends at the NEXT midnight
        (00:00), on the same grid as every other point. null means "no data",
        deliberately distinct from a measured 0. Each series also reports
        `point_count`.

        Buckets are cut on the installation's timezone (see get_system_info),
        not UTC: a "1d" bucket is a local calendar day, including the 23- or
        25-hour day of a daylight-saving switch.

        A _grid/_pv power split is answered only over a timeframe that has
        ENDED, and never finer than "5m". #{Facts::SPLIT_CADENCE} So a running
        window ends in buckets with no split yet. Ask for a past day, week or
        month instead; "5m" is as fine as a split gets, whatever else you
        change.

        #{Facts::UNKNOWN_SENSORS}

        #{Facts::TIMEFRAME_NOTE} A forecast sensor over a future timeframe is
        normal and gets none.
      TEXT
      input_schema(
        properties: {
          sensors:
            sensors_property(
              "Sensor names (from list_sensors), at most #{MAX_SENSORS}.",
              max: MAX_SENSORS,
            ),
          timeframe: timeframe_property('The period the curve covers.'),
          resolution: {
            type: 'string',
            enum: %w[1m 5m 15m 1h 1d],
            description: 'Bucket size. Defaults to the finest that fits the point limit.',
          },
          aggregation: {
            type: 'string',
            enum: %w[mean min max],
            default: 'mean',
            # Why there is no "sum" is stated twice in the description already.
            description: 'Per-bucket aggregation.',
          },
          include_nulls: {
            type: 'boolean',
            default: true,
            description:
              'Keep empty buckets. false omits them, which shrinks the response ' \
                'a lot for sporadically written sensors and keeps a finer ' \
                'resolution on the running period.',
          },
        },
        required: %w[sensors timeframe],
      )
      read_only idempotent: true

      def self.perform(
        sensors:,
        timeframe:,
        resolution: nil,
        aggregation: 'mean',
        include_nulls: true,
        **
      )
        tf = parse_timeframe(timeframe)
        raise ArgumentError, 'Timeframe must cover a span, not the "now" instant.' if tf.now?

        definitions, unknown = resolve_sensors(sensors, max: MAX_SENSORS)

        enforce_supported!(definitions, :series)
        enforce_completed_timeframe!(definitions, tf)

        agg = Aggregation.internal(aggregation)
        interval, label, coarsened_by =
          Resolution.for(resolution, tf, definitions, include_nulls:)

        data =
          Sensor::Query::Series.new(
            definitions.map(&:name),
            tf,
            interval:,
            aggregation: agg,
            timestamp_method: :to_time,
          ).call

        {
          # A timeframe in the future is the whole point of a forecast sensor,
          # so the "nothing measured yet" note only applies without one.
          **timeframe_preamble(tf, unknown, note: definitions.none?(&:forecast?)),
          resolution: label,
          coarsened: !coarsened_by.nil?,
          **Resolution.explain(coarsened_by, resolution, label, definitions.size),
          aggregation:,
          series:
            definitions.map { |sensor| series_for(sensor, data, agg, tf, include_nulls:) },
        }
      end

      # A power split is exact only once its window has ENDED (see
      # Facts::SPLIT_CADENCE): the newest buckets of a running window carry a
      # base value whose split does not exist yet. That is a per-call condition
      # the `s` flag cannot express, so it is enforced here rather than by
      # withholding the letter - a curve over a finished window is sound.
      def self.enforce_completed_timeframe!(definitions, timeframe)
        splits = definitions.reject(&:instantaneous?)
        return if splits.none? || timeframe.past?

        raise ArgumentError,
              'A _grid/_pv power split is only exact over a timeframe that has ' \
                "ENDED. #{Facts::SPLIT_CADENCE} Ask for a past day, week or month " \
                'instead, or use get_totals. Affected: ' \
                "#{splits.map(&:name).join(', ')}."
      end
      private_class_method :enforce_completed_timeframe!

      def self.series_for(sensor, data, aggregation, timeframe, include_nulls:)
        unit = mcp_unit(sensor)
        points =
          Points.build(data, sensor.name, aggregation, unit:, include_nulls:, timeframe:)

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
