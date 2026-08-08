module McpServer
  module Tools
    # Returns a time-ordered measurement series for one or more sensors, down to
    # sub-daily resolution (InfluxDB). This is what reveals intraday curves that
    # the daily-aggregated tools cannot show.
    class Series < Base
      tool_name 'get_series'
      title 'Get a time series for sensors'

      # The longest timeframe this tool answers, and the line between the two
      # data stores: InfluxDB holds the raw samples a curve is drawn from,
      # PostgreSQL the per-period summaries. A bucket mean drifts from the
      # energy the summaries integrate, so the wider the window, the more a
      # curve costs and the less it is worth - a month asked here is a
      # get_totals or get_ranking question.
      #
      # 99 hours because that is the longest window the Timeframe grammar
      # states in hours ("P99H"). The UI stops at 72, but nothing in the data
      # does, and a bound taken from the grammar needs no second rule to
      # explain it. It is not a round number of days on purpose: the longest
      # date range it admits is 4 days, which stays 4 days across a
      # daylight-saving switch, where a 72-hour bound would have accepted a
      # 3-day range in June and rejected the same one in October.
      MAX_SPAN = 99.hours
      public_constant :MAX_SPAN

      description <<~TEXT.strip
        Chronological measurement series for one or more sensors, down to
        sub-daily resolution — the intraday curves the aggregated tools cannot
        show ("consumption per hour yesterday", "battery SoC since this
        morning", "nightly base load").

        A SHORT window only: raw InfluxDB samples, at most
        #{MAX_SPAN.in_hours.to_i} hours ("P#{MAX_SPAN.in_hours.to_i}H", or a
        4-day range); a longer one is REJECTED. Anything from a week
        upwards is a summary question — get_totals for the total,
        get_ranking(sort: "chronological") for a value per period, with a
        period coarse enough that the span fits its #{Ranking::MAX_LIMIT}
        entries. Both read PostgreSQL, exact per period rather than a mean per
        bucket. A forecast sensor is exempt: no summary holds its horizon.

        These are averaged value curves, NOT an energy source: a bucket holds
        the unweighted mean of its samples, so integrating a coarse series
        drifts from what the summaries hold — upward for a sensor written on
        change, whose idle minutes carry no samples, by up to a multiple. The
        averaged ratios drift with it (autarky, self-consumption rate), the
        more so the coarser the bucket. For period totals (kWh, costs) and for
        ratios, get_totals and get_ranking are the accurate answer.

        Each point is {time, value}, `time` being the END of its bucket: at
        "5m" the point 07:05 covers 07:00–07:05, and a day's last bucket ends
        at the NEXT midnight (00:00), on the same grid as every other point. A
        null value means "no data", distinct from a measured 0. Buckets are cut
        on the installation's timezone (get_system_info), so they follow local
        time across a daylight-saving switch.

        Resolution, when omitted: the finest that keeps the WHOLE response
        within #{Resolution::MAX_POINTS} points — a budget SHARED by the
        requested sensors, so N of them get #{Resolution::MAX_POINTS}/N each.
        Exactly three things coarsen a request: that budget; the forecast
        cadence, flooring forecast sensors alone at "15m"; and the Power
        Splitter cycle, flooring _grid/_pv splits alone at "5m". Nothing else,
        so a coarser request never yields a coarser result than a finer one.
        Read back `resolution` and `coarsened`; `coarsened_reason` names the
        constraint and what to change. Where even "1h" does not fit, the
        request is rejected rather than answered over budget: a whole day costs
        24 points per sensor, so a day is answered for 16 sensors at most.

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
          timeframe:
            timeframe_property(
              'The period the curve covers, at most ' \
                "#{MAX_SPAN.in_hours.to_i} hours.",
            ),
          resolution: {
            type: 'string',
            enum: %w[1m 5m 15m 1h],
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

        enforce_supported!(definitions, :series, unknown)
        enforce_short_timeframe!(definitions, tf)
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

      # Forecast sensors are exempt: their curve is a provider's horizon rather
      # than a measurement, no summary holds it, and the forecast floor already
      # caps what such a request can cost. The point budget still binds.
      def self.enforce_short_timeframe!(definitions, timeframe)
        return if definitions.all?(&:forecast?)

        span = (timeframe.ending - timeframe.beginning).to_i
        return if span <= MAX_SPAN

        hours = MAX_SPAN.in_hours.to_i

        raise ArgumentError,
              'get_series reads raw measurements and answers at most ' \
                "#{hours} hours (\"P#{hours}H\"); this timeframe spans " \
                "#{span.fdiv(1.day).ceil} days. Its buckets are means " \
                'over samples, which drift from the energy a longer period ' \
                'holds. Use get_totals for the total over the period, or ' \
                'get_ranking(sort: "chronological") for a value per period. ' \
                "A ranking returns at most #{Ranking::MAX_LIMIT} entries, so " \
                'ask it for period "day" over a span of that many days, and ' \
                'for "week", "month" or "year" over a longer one. Both read ' \
                'the summaries, which are exact per period.'
      end
      private_class_method :enforce_short_timeframe!

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
          display_name: mcp_display_name(sensor),
          unit:,
          point_count: points.size,
          points:,
        }
      end
      private_class_method :series_for
    end
  end
end
