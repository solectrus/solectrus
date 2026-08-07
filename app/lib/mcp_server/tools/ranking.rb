module McpServer
  module Tools
    # Ranks days/weeks/months/years by a sensor value over a timeframe, directly
    # from the PostgreSQL summaries. Answers "which day had the most/least ..."
    # without iterating over every single day.
    class Ranking < Base
      tool_name 'get_ranking'
      title 'Rank days/weeks/months by a sensor'
      description <<~TEXT.strip
        Rank the best or worst periods for one or more sensors over a timeframe:
        "which day this year had the highest solar production", "the 5 coldest
        days last winter", "house consumption per day in March". Returns, per
        sensor, a list of periods with their aggregated value.

        Units: #{Facts::WATT_SUM_IS_ENERGY} Only a sensor the summaries store can
        be ranked; a derived one is rejected by name.

        `aggregation` defaults to each sensor's natural one, `period` to "day",
        `order` to "desc" — which also decides WHICH periods the limit keeps.

        A period the timeframe cuts into carries `partial: true`, and only
        then. Each entry is labelled with its period's START, but summed over
        the days inside the timeframe alone: with period="month" over
        "2026-06-15..2026-07-15" the entry dated "2026-06-01" holds June 15-30,
        not June — half the month under a label claiming all of it. The date
        may even fall before the timeframe ("2025-12-29" for the first week of
        year "2026"). So never compare a flagged entry with an unflagged one
        directly — the fragment is smaller for having been cut, not for having
        produced less. The current period is flagged the same way, being
        equally unfinished — today included, under the default period="day".

        Some rankings leave cut periods OUT instead, where a fragment would win
        for being one: order="asc" (the lowest month is never the one that just
        started) and every averaged ratio (autarky, self-consumption rate — an
        average is not smaller for covering less, so both directions). Those
        carry `complete_periods_only: true` and span less than the timeframe
        names — the edge periods are missing from the LIST, not from the data.

        sort="chronological" returns the selected periods in date order, ready
        to plot as a trend curve without re-sorting. There, a period between the
        first and the last entry that has no data is reported with value null,
        so "no data point" stays distinct from "the value was 0". Nothing is
        padded outside that span — the first and last entry tell you the range
        actually covered — and a list truncated by `limit` is left alone, since
        a period missing there may simply not have made the cut. A value ranking
        (the default) never reports such periods, so pair "chronological" with a
        generous limit to get a full curve.

        #{Facts::TIMEFRAME_NOTE}
      TEXT
      input_schema(
        properties: {
          sensors:
            sensors_property(
              "Sensor names (from list_sensors), at most #{MAX_SENSORS}.",
              max: MAX_SENSORS,
            ),
          sensor: {
            type: 'string',
            description: 'Single sensor name (alternative to "sensors").',
          },
          timeframe: timeframe_property('The range to rank within.'),
          period: {
            type: 'string',
            enum: %w[day week month year],
            default: 'day',
            description: 'Granularity of each ranked entry.',
          },
          aggregation: {
            type: 'string',
            enum: %w[sum max avg min],
            description:
              "Defaults to the sensor's natural one. Only what " \
                'get_sensor_details lists under `aggregations` is accepted.',
          },
          order: {
            type: 'string',
            enum: %w[desc asc],
            default: 'desc',
            description: '"desc" = highest first, "asc" = lowest first.',
          },
          sort: {
            type: 'string',
            enum: %w[value chronological],
            default: 'value',
            description: '"value" or "chronological" (date order).',
          },
          limit: {
            type: 'integer',
            minimum: 1,
            maximum: 100,
            default: 10,
            description: 'Entries per sensor.',
          },
        },
        required: %w[timeframe],
      )
      read_only idempotent: true

      def self.perform( # rubocop:disable Metrics/ParameterLists
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
        definitions, unknown = resolve_sensors(requested, max: MAX_SENSORS)

        enforce_rankable!(definitions)

        tf = parse_timeframe(timeframe)
        options = {
          timeframe: tf,
          period: period.to_sym,
          aggregation:,
          desc: order.to_s != 'asc',
          chronological: sort.to_s == 'chronological',
          limit: limit.to_i.clamp(1, 100),
        }

        {
          **timeframe_preamble(tf, unknown),
          period:,
          order:,
          sort:,
          results: definitions.map { |definition| rank(definition, options) },
        }
      end

      def self.rank(sensor, options)
        agg = (options[:aggregation] || sensor.default_aggregation)&.to_sym
        unless agg
          raise ArgumentError,
                "Sensor #{sensor.name} has no natural aggregation; pass an explicit `aggregation`"
        end

        rows, complete_only = Rows.fetch(sensor, **options, aggregation: agg)
        unit = mcp_unit(sensor, agg)

        {
          sensor: sensor.name,
          display_name: sensor.display_name,
          unit:,
          aggregation: agg,
          # Set only where it applies, and then the whole signal: this ranking
          # left the cut periods out, so it spans less than the timeframe names
          # and entries are missing rather than absent from the data.
          **(complete_only ? { complete_periods_only: true } : {}),
          # Rows carries the `partial` marker where there is one; splatting the
          # row keeps it without this layer having to know about it.
          ranking:
            rows.map do |row|
              { **row, date: row[:date].iso8601, value: Precision.round(row[:value], unit) }
            end,
        }
      end
      private_class_method :rank
    end
  end
end
