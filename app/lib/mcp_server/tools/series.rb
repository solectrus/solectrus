module McpServer
  module Tools
    # Returns a time-ordered measurement series for one or more sensors, down to
    # sub-daily resolution (InfluxDB). This is what reveals intraday curves that
    # the daily-aggregated tools cannot show.
    class Series < Base
      # Resolutions offered to the client, ascending, mapped to seconds.
      RESOLUTIONS = [
        ['1m', 60],
        ['5m', 300],
        ['15m', 900],
        ['1h', 3600],
        ['1d', 86_400],
      ].freeze
      private_constant :RESOLUTIONS

      # Hard cap on points per sensor; the resolution is coarsened until the
      # series fits within it.
      MAX_POINTS = 1500
      private_constant :MAX_POINTS

      # Hard cap on sensors per request. Each sensor is a separate InfluxDB
      # subquery yielding up to MAX_POINTS, so bound the per-request work even
      # though resolve_sensors already restricts to the configured set.
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
          - sensors: machine names (from list_sensors), one or more.
          - timeframe: SOLECTRUS notation, e.g. "2026-06-21" (a day), "2026-W25"
            (a week), "2025-01-15..2025-02-12" (a range), "P24H" (last 24h).
          - resolution: "1m", "5m", "15m", "1h" or "1d". When omitted, defaults
            to the finest resolution (down to 1m) that keeps the series within
            #{MAX_POINTS} points. A too-fine resolution is automatically
            coarsened; the resolution actually used is returned in the response.
          - aggregation: "mean" (default, the value curve), "sum", "min" or
            "max" — applied per resolution bucket.

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
            description: 'Sensor machine names (from list_sensors).',
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
            enum: %w[mean sum min max],
            description: 'Per-bucket aggregation. Defaults to "mean".',
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

        agg = internal_aggregation(aggregation)
        interval, label = resolution_for(resolution, tf)

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
          aggregation:,
          series: definitions.map { |sensor| series_for(sensor, data, agg) },
        )
      rescue ArgumentError => e
        error_response(e.message)
      end

      # Translate the client-facing aggregation ("mean") to the internal symbol
      # the query layer expects (:avg); sum/min/max pass through.
      def self.internal_aggregation(aggregation)
        aggregation.to_s == 'mean' ? :avg : aggregation.to_sym
      end
      private_class_method :internal_aggregation

      # Pick the bucket: start at the requested resolution (or the finest when
      # unset/unknown) and coarsen until the series fits within MAX_POINTS.
      # Falls back to the coarsest bucket for extreme spans.
      def self.resolution_for(resolution, timeframe)
        span = (timeframe.ending - timeframe.beginning).to_i
        start = RESOLUTIONS.index { |label, _| label == resolution } || 0

        label, seconds =
          RESOLUTIONS[start..].find { |_label, secs| span.fdiv(secs).ceil <= MAX_POINTS } ||
          RESOLUTIONS.last

        [seconds, label]
      end
      private_class_method :resolution_for

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
          unit: sensor.unit,
          points: (raw || {}).sort.map! { |time, value| { time: time.iso8601, value: } },
        }
      end
      private_class_method :series_for
    end
  end
end
