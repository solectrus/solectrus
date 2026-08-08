module McpServer
  module Tools
    # Ranks days/weeks/months/years by a sensor value over a timeframe, directly
    # from the PostgreSQL summaries. Answers "which day had the most/least ..."
    # without iterating over every single day.
    class Ranking < Base
      tool_name 'get_ranking'
      title 'Rank days/weeks/months by a sensor'

      # Entries per sensor a single ranking may return. It bounds what one
      # response costs, and it bounds the SPAN a chronological curve can cover:
      # beyond it a client has to ask for a coarser period, which is why
      # get_series names this number when it sends one here.
      MAX_LIMIT = 100
      public_constant :MAX_LIMIT

      # Entries across the WHOLE response, shared by the requested sensors -
      # the same idea as the point budget in get_series, and for the same
      # reason: what reaches the client is one context window, not one per
      # sensor.
      #
      # An entry costs about 6 bytes now that the axis is stated once, so the
      # unbounded worst case (20 sensors x 100 entries) is ~12 kB rather than
      # the 65 kB that first justified a cap. The cap stays anyway: MAX_LIMIT
      # bounds one sensor, and without this nothing bounds their sum.
      #
      # 400 keeps every request that was reasonable before: a single sensor
      # still gets the full MAX_LIMIT, and so does a request of up to four. Only
      # beyond that does the list per sensor shorten, which is also where a
      # client is asking for a table it cannot read anyway.
      MAX_ENTRIES = 400
      public_constant :MAX_ENTRIES

      description <<~TEXT.strip
        Rank the best or worst periods for one or more sensors over a
        timeframe: "which day this year had the highest solar production", "the
        5 coldest days last winter", "house consumption per day in March".
        Returns, per sensor, a list of periods with their aggregated `value`
        and the `unit` it carries after aggregation (a summed watt sensor
        reports watt_hour). Only a sensor the summaries store, and that has an
        aggregation to order by, can be ranked — the rest carry no "r" in
        their `tools` and are rejected by name.

        `order` decides WHICH periods the limit keeps, not just their sequence.

        A period the timeframe cuts into is listed in `partial_at`, and only
        then — the period still running included, today under the default
        period="day". Such an entry covers its period's START but is summed
        over the days inside the timeframe alone: with period="month" over
        "2026-06-15..2026-07-15" the entry at "2026-06-01" holds June 15-30.
        Its period may even begin before the timeframe ("2025-12-29" for the
        first week of "2026"). Never compare a flagged entry with an unflagged
        one: it is smaller for having been cut, not for having produced less.

        Where a fragment would instead WIN for being one, cut periods are left
        out: order="asc" and every averaged ratio (autarky, self-consumption
        rate — an average is not smaller for covering less, so both
        directions). Those results carry `complete_periods_only: true` and span
        less than the timeframe names — the edge periods are missing from the
        LIST, not from the data.

        On the axis: `start` is the EARLIEST period in the list, which under
        sort="value" is NOT the first entry — that ordering is by size, so it
        always carries `indices` too.

        sort="chronological" returns the selected periods in date order, ready
        to plot. A period without data between the first and the last entry is
        reported with value null, distinct from a measured 0; nothing is padded
        outside that span, and a list truncated by `limit` is left alone (a
        period missing there may simply not have made the cut). A value ranking
        never reports such periods, so pair "chronological" with a generous
        limit for a full curve.

        `limit` counts per sensor but the budget is SHARED: N sensors get
        #{MAX_ENTRIES}/N entries each at most, so a long list and many sensors
        need separate calls. Read back `limit`; `limit_note` says when the
        budget shortened it.
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
            description: 'Order of the returned entries.',
          },
          limit: {
            type: 'integer',
            minimum: 1,
            maximum: MAX_LIMIT,
            default: 10,
            description:
              "Entries per sensor, capped by a budget of #{MAX_ENTRIES} " \
                'shared by all requested sensors.',
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
        definitions, unknown =
          resolve_sensors(
            requested,
            max: MAX_SENSORS,
            blank_message:
              'Provide a sensor to rank: `sensors` for a list, or `sensor` ' \
                'for a single name. Call list_sensors for the names this ' \
                'instance has.',
          )
        enforce_supported!(definitions, :ranking, unknown)

        tf = parse_timeframe(timeframe)
        effective = effective_limit(limit, definitions.size)
        options = {
          timeframe: tf,
          period: period.to_sym,
          aggregation:,
          desc: order.to_s != 'asc',
          chronological: sort.to_s == 'chronological',
          limit: effective,
        }

        {
          **timeframe_preamble(tf, unknown),
          period:,
          order:,
          sort:,
          limit: effective,
          **limit_note(limit, effective, definitions.size),
          results: definitions.map { |definition| rank(definition, options) },
        }
      end

      # The entries one sensor gets: what the client asked for, unless the
      # shared budget cannot pay for it. The schema states MAX_LIMIT too, so the
      # clamp is the backstop for a client that ignores it.
      def self.effective_limit(requested, sensor_count)
        share = (MAX_ENTRIES / sensor_count).clamp(1, MAX_LIMIT)

        requested.to_i.clamp(1, share)
      end
      private_class_method :effective_limit

      # Why the list is shorter than asked for, as a hash to splat into the
      # response - empty when nothing was cut, so the common case pays nothing.
      # A silently shortened list is the one thing a chronological ranking must
      # not do: it reads as "the data ends here" rather than "the budget did".
      def self.limit_note(requested, effective, sensor_count)
        return {} if effective >= requested.to_i.clamp(1, MAX_LIMIT)

        {
          limit_note:
            "Requested #{requested}, returning #{effective} entries per " \
              "sensor: #{sensor_count} sensors share a budget of " \
              "#{MAX_ENTRIES} entries. Ask for fewer sensors to get a longer " \
              'list, or repeat the call per sensor.',
        }
      end
      private_class_method :limit_note

      # `default_aggregation` is guaranteed here: the `ranking` flag has already
      # rejected every sensor whose allowed list is empty, which is the only way
      # it can be nil.
      def self.rank(sensor, options)
        agg = (options[:aggregation] || sensor.default_aggregation).to_sym
        rows, complete_only = Rows.fetch(sensor, **options, aggregation: agg)
        unit = mcp_unit(sensor, agg)

        rounded = rows.map { |row| row.merge(value: Precision.round(row[:value], unit)) }

        {
          sensor: sensor.name,
          display_name: mcp_display_name(sensor),
          unit:,
          aggregation: agg,
          # Set only where it applies, and then the whole signal: this ranking
          # left the cut periods out, so it spans less than the timeframe names
          # and entries are missing rather than absent from the data.
          **(complete_only ? { complete_periods_only: true } : {}),
          **Rows.axis(rounded, options[:period]),
        }
      end
      private_class_method :rank
    end
  end
end
