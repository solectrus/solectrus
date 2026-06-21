module McpServer
  module Tools
    # Ranks days/weeks/months/years by a sensor value over a timeframe, directly
    # from the PostgreSQL summaries. Answers "which day had the most/least ..."
    # without iterating over every single day.
    class Ranking < Base
      tool_name 'get_ranking'
      title 'Rank days/weeks/months by a sensor'
      description <<~TEXT.strip
        Rank the best or worst periods for one or more sensors over a timeframe,
        e.g. "which day this year had the highest solar production", "the 5
        coldest days last winter", or "house consumption per day in March".
        Returns, per sensor, a list of periods with their aggregated value.

        Parameters:
          - sensors: machine names (from list_sensors), one or more. A single
            "sensor" is also accepted. Defaults to all sensors when omitted.
          - timeframe: the range to look at, in SOLECTRUS notation, e.g. "2026"
            (this year), "2026-06" (a month), "2026-01-01..2026-03-31" (range),
            "all" (since installation).
          - period: granularity of each ranked entry ("day", "week", "month",
            "year"). Defaults to "day".
          - aggregation: "sum" (energy/money), "max", "avg" or "min". Defaults to
            each sensor's natural aggregation.
          - order: "desc" (highest first, default) or "asc" (lowest first) -
            selects which periods the limit keeps.
          - sort: "value" (default) keeps the value ranking; "chronological"
            returns the selected periods in date order, ready to plot as a trend
            curve (e.g. an outage spanning several days) without re-sorting.
          - limit: how many entries to return per sensor (1-100, default 10).
            Use a generous limit with sort="chronological" to get a full curve.
      TEXT
      input_schema(
        properties: {
          sensors: {
            type: 'array',
            items: {
              type: 'string',
            },
            description:
              'Sensor machine names (from list_sensors). Defaults to all sensors when omitted.',
          },
          sensor: {
            type: 'string',
            description: 'Single sensor machine name (alternative to "sensors").',
          },
          timeframe: {
            type: 'string',
            description:
              'Range to rank within, e.g. "2026", "2026-06", "2026-01-01..2026-03-31", "all".',
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
        definitions = resolve_sensors(requested, allow_blank: true)

        # When defaulting to all sensors, drop those without a natural
        # aggregation (nothing meaningful to rank) unless the caller forces one.
        if requested.blank? && aggregation.blank?
          definitions = definitions.select(&:default_aggregation)
        end

        tf = Timeframe.new(timeframe)
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
          period:,
          order:,
          sort:,
          results: definitions.map { |definition| rank(definition, **options) },
        )
      rescue ArgumentError => e
        error_response(e.message)
      end

      def self.rank(sensor, timeframe:, period:, aggregation:, desc:, chronological:, limit:) # rubocop:disable Metrics/ParameterLists
        agg = aggregation || sensor.default_aggregation
        unless agg
          raise ArgumentError,
                "Sensor #{sensor.name} has no natural aggregation; pass an explicit `aggregation`"
        end
        agg = agg.to_sym

        rows =
          Sensor::Query::Ranking.new(
            sensor.name,
            aggregation: agg,
            period:,
            start: timeframe.effective_beginning_date,
            stop: timeframe.effective_ending_date,
            desc:,
            limit:,
          ).call

        rows = rows.sort_by { |entry| entry[:date] } if chronological

        {
          sensor: sensor.name,
          display_name: sensor.display_name,
          unit: sensor.unit,
          aggregation: agg,
          ranking: rows.map { |entry| { date: entry[:date].iso8601, value: entry[:value] } },
        }
      end
      private_class_method :rank
    end
  end
end
