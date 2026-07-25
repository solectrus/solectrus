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
          - resolution: "1m", "5m", "15m", "1h" or "1d". When omitted, defaults
            to the finest resolution (down to 1m) that keeps the WHOLE response
            within #{Resolution::MAX_POINTS} points across all requested sensors — so with N
            sensors each series is capped at #{Resolution::MAX_POINTS}/N points, not
            #{Resolution::MAX_POINTS} each. A too-fine resolution — whether explicitly
            requested or the default — is automatically coarsened, for exactly
            two reasons: to stay within that shared point budget, and because
            forecast sensors carry at most one sample per 15 minutes, so a
            request for forecast sensors alone is never answered finer than
            "15m" (it would be mostly null). Nothing else coarsens a request:
            asking for a coarser resolution never gives you a coarser result
            than asking for a finer one. The resolution actually used is always
            returned as `resolution`, and `coarsened: true` flags that it is
            coarser than the one you requested — read these back rather than
            assuming the requested one was honoured.
          - aggregation: "mean" (default, the value curve), "min" or "max" —
            applied per resolution bucket. There is deliberately no "sum":
            summing a coarse series is not an energy integration and reads as a
            misleading total. For period totals (Wh/kWh, costs) use get_totals,
            for the forecast use get_forecast.

        Each point is {time, value}. A value of null means "no data" (e.g. a
        sensor was offline) and is deliberately distinct from a measured 0.
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
        },
        required: %w[sensors timeframe],
      )
      read_only idempotent: true

      def self.call(sensors:, timeframe:, resolution: nil, aggregation: 'mean', **)
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
        interval, label = Resolution.for(resolution, tf, definitions)

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
          coarsened: Resolution.coarsened?(resolution, label),
          aggregation:,
          series: definitions.map { |sensor| series_for(sensor, data, agg) },
        )
      rescue ArgumentError => e
        error_response(e.message)
      end

      def self.series_for(sensor, data, aggregation)
        # `data` exposes an accessor for every requested sensor: raw sensors via
        # Data::Series, derived sensors via the singleton accessor that
        # process_calculated_sensors installs (house_power - sum(custom_power),
        # autarky, ...). A raw sensor without any data returns nil, hence the
        # `|| {}` guard.
        raw =
          if data.respond_to?(sensor.name)
            data.public_send(sensor.name, aggregation, aggregation)
          end

        {
          sensor: sensor.name,
          display_name: sensor.display_name,
          unit: mcp_unit(sensor),
          points:
            (raw || {}).sort.map! do |time, value|
              { time: time.iso8601, value: normalize_value(value) }
            end,
        }
      end
      private_class_method :series_for

      # Flux can hand back a signed negative zero (e.g. a sensor sitting at 0
      # around midday), which serialises as "-0.0". Collapse it to a plain 0.0
      # so the JSON output never carries a negative zero.
      def self.normalize_value(value)
        return 0.0 if value.is_a?(Float) && value.zero?

        value
      end
      private_class_method :normalize_value
    end
  end
end
