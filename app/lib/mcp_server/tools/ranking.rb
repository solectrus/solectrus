module McpServer
  module Tools
    # Ranks days/weeks/months/years by a sensor value over a timeframe, directly
    # from the PostgreSQL summaries. Answers "which day had the most/least ..."
    # without iterating over every single day.
    class Ranking < Base
      # Each sensor is ranked with its own query, so bound the per-request work
      # and require the caller to name the sensors instead of fanning out to all.
      MAX_SENSORS = 20
      private_constant :MAX_SENSORS

      tool_name 'get_ranking'
      title 'Rank days/weeks/months by a sensor'
      description <<~TEXT.strip
        Rank the best or worst periods for one or more sensors over a timeframe:
        "which day this year had the highest solar production", "the 5 coldest
        days last winter", "house consumption per day in March". Returns, per
        sensor, a list of periods with their aggregated value.

        Units: like get_totals, a summed power sensor ranks ENERGIES, so each
        value is in Wh, not W (divide by 1000 for kWh).

        `aggregation` defaults to each sensor's natural one, `period` to "day",
        `order` to "desc" — which also decides WHICH periods the limit keeps.

        sort="chronological" returns the selected periods in date order, ready
        to plot as a trend curve without re-sorting. There, a period between the
        first and the last entry that has no data is reported with value null,
        so "no data point" stays distinct from "the value was 0". Nothing is
        padded outside that span — the first and last entry tell you the range
        actually covered — and a list truncated by `limit` is left alone, since
        a period missing there may simply not have made the cut. A value ranking
        (the default) never reports such periods, so pair "chronological" with a
        generous limit to get a full curve.

        A timeframe that cannot hold data at all — entirely in the future, or
        ending before the installation date — answers with an empty ranking plus
        a `timeframe_note` saying which of the two it is.
      TEXT
      input_schema(
        properties: {
          sensors: {
            type: 'array',
            items: {
              type: 'string',
            },
            description:
              "Sensor names (from list_sensors), one or more (max #{MAX_SENSORS}).",
          },
          sensor: {
            type: 'string',
            description: 'Single sensor name (alternative to "sensors").',
          },
          timeframe: {
            type: 'string',
            description:
              'Range to rank within: "2026", "2026-06", "2026-W25", ' \
                '"2026-01-01..2026-03-31", "P30D"/"P12M", "all" (since installation).',
          },
          period: {
            type: 'string',
            enum: %w[day week month year],
            description: 'Granularity of each ranked entry. Defaults to "day".',
          },
          aggregation: {
            type: 'string',
            enum: %w[sum max avg min],
            description: "Defaults to each sensor's natural aggregation.",
          },
          order: {
            type: 'string',
            enum: %w[desc asc],
            description: '"desc" = highest first (default), "asc" = lowest first.',
          },
          sort: {
            type: 'string',
            enum: %w[value chronological],
            description: '"value" (default) or "chronological" (date order).',
          },
          limit: {
            type: 'integer',
            description: 'Entries per sensor (1-100). Defaults to 10.',
          },
        },
        required: %w[timeframe],
      )
      read_only idempotent: true

      def self.call( # rubocop:disable Metrics/ParameterLists
        timeframe:,
        sensors: nil,
        sensor: nil,
        period: 'day',
        aggregation: nil,
        order: 'desc',
        sort: 'value',
        limit: 10,
        **
      )
        requested = Array(sensors) | Array(sensor)
        definitions = resolve_sensors(requested)
        if definitions.size > MAX_SENSORS
          raise ArgumentError, "Too many sensors (max #{MAX_SENSORS})"
        end

        tf = parse_timeframe(timeframe)
        options = {
          timeframe: tf,
          period: period.to_sym,
          aggregation:,
          desc: order.to_s != 'asc',
          chronological: sort.to_s == 'chronological',
          limit: limit.to_i.clamp(1, 100),
        }

        json_response(
          timeframe: tf.to_s,
          **timeframe_note(tf),
          period:,
          order:,
          sort:,
          results: definitions.map { |definition| rank(definition, options) },
        )
      rescue ArgumentError => e
        error_response(e.message)
      end

      def self.rank(sensor, options)
        agg = (options[:aggregation] || sensor.default_aggregation)&.to_sym
        unless agg
          raise ArgumentError,
                "Sensor #{sensor.name} has no natural aggregation; pass an explicit `aggregation`"
        end

        rows = Rows.fetch(sensor, **options, aggregation: agg)
        unit = mcp_unit(sensor, agg)

        {
          sensor: sensor.name,
          display_name: sensor.display_name,
          unit:,
          aggregation: agg,
          ranking:
            rows.map do |entry|
              { date: entry[:date].iso8601, value: Precision.round(entry[:value], unit) }
            end,
        }
      end
      private_class_method :rank
    end
  end
end
