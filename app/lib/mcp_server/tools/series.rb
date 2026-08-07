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
        week", "nightly base load").

        These are averaged value curves, NOT an energy source: a bucket holds
        the unweighted mean of its samples, so integrating a coarse series
        drifts from what the summaries hold — upward for a sensor written on
        change, whose idle minutes carry no samples, by up to a multiple. The
        averaged ratios drift with it (autarky, self-consumption rate), by a
        few tenths of a point at "1d". For period totals (kWh, costs) and for
        ratios, get_totals and get_ranking are the accurate answer.

        Each point is {time, value}, `time` being the END of its bucket: at
        "5m" the point 07:05 covers 07:00–07:05, and a day ends at the NEXT
        midnight (00:00), on the same grid as every other point. A null value
        means "no data", distinct from a measured 0. Buckets are cut on the
        installation's timezone (get_system_info), so a "1d" bucket is a local
        calendar day — 23 or 25 hours across a daylight-saving switch.

        Resolution, when omitted: the finest that keeps the WHOLE response
        within #{Resolution::MAX_POINTS} points — a budget SHARED by the
        requested sensors, so N of them get #{Resolution::MAX_POINTS}/N each.
        Exactly three things coarsen a request: that budget; the forecast
        cadence, flooring forecast sensors alone at "15m"; and the Power
        Splitter cycle, flooring _grid/_pv splits alone at "5m". Nothing else,
        so a coarser request never yields a coarser result than a finer one.
        Read back `resolution` and `coarsened`; `coarsened_reason` names the
        constraint and what to change.

        A _grid/_pv power split is answered only over a timeframe that has
        ENDED. #{Facts::SPLIT_CADENCE} A running window ends in buckets with no
        split yet.
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
            description: 'Bucket size. Defaults to the finest that fits the point budget.',
          },
          aggregation: {
            type: 'string',
            enum: %w[mean min max],
            default: 'mean',
            description:
              'Per bucket. "mean" is the curve the SOLECTRUS UI shows; ' \
                '"max"/"min" give the extreme sample, so "max" at a fine ' \
                'resolution is the true instantaneous peak. No "sum" - summing ' \
                'a coarse series is not an energy integration.',
          },
          include_nulls: {
            type: 'boolean',
            default: true,
            description:
              'Keep empty buckets. false omits them - far smaller for ' \
                'sporadically written sensors, and the rest stay on the same ' \
                'grid, so a gap reads like an explicit null. It also buys ' \
                'resolution on a running period, whose buckets still ahead ' \
                'then cost no budget.',
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
