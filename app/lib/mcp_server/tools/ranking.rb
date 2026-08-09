module McpServer
  module Tools
    # Ranks days/weeks/months/years by a sensor value over a timeframe, directly
    # from the PostgreSQL summaries. Answers "which day had the most/least ..."
    # without iterating over every single day.
    class Ranking < Base
      tool_name 'get_ranking'
      title 'Rank days/weeks/months by a sensor'

      # Entries per sensor a single ranking may return, bounding what one
      # response costs. A top-N list has no reason to be longer; a client that
      # wanted the periods themselves rather than the biggest of them is
      # asking get_periods.
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

      # Kept to what a client needs BEFORE it calls: which sensors can be
      # ranked, what `order` decides, how a cut period reads, the shared entry
      # budget, and the tool for the question this one does not answer. What
      # the response says about itself - `limit_note`, `complete_periods_only`,
      # `unknown_sensors` - is left to the response.
      description <<~TEXT.strip
        Rank the best or worst periods for one or more sensors over a
        timeframe: "which day this year had the highest solar production",
        "the three cheapest months". Returns, per sensor, a list of periods
        with their aggregated `value` and its `unit`, ordered BY SIZE. Only a
        sensor the summaries store, and that has an aggregation to order by,
        can be ranked — the rest carry no "r" in their `tools` and are rejected
        by name.

        `order` decides WHICH periods the limit keeps, not just their sequence.

        An entry is labelled with its period START but summed over the days
        inside the timeframe alone, so a period the timeframe cuts into is a
        fragment: with period="month" over "2026-06-15..2026-07-15" the entry
        "2026-06-01" holds June 15-30. `partial_at` names those periods, the
        one still running included — today under the default period="day".

        Where a fragment would instead WIN for being one, cut periods are left
        out and `complete_periods_only` says so: order="asc", and
        aggregation="avg" in either direction (an average is not smaller for
        covering less).

        Ordered by size, `start` is the EARLIEST period rather than the first
        entry, and `indices` gives each entry's offset from it in `period`
        steps — never a position in `values`. For the same periods in DATE
        order, dense and ready to plot, ask get_periods.

        `limit` counts per sensor but the budget is SHARED: N sensors get
        #{MAX_ENTRIES}/N entries each at most, so a long list and many sensors
        need separate calls.
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
        sort: nil,
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

        # After the validations, so a rejected call spends no time building
        # summaries it will not read. A ranking reads nothing else, so a day
        # without a summary does not rank low - it is absent from the list.
        pending = McpServer::Summaries.refresh(tf)

        effective = effective_limit(limit, definitions.size)
        options = {
          timeframe: tf,
          period: period.to_sym,
          aggregation:,
          desc: order.to_s != 'asc',
          limit: effective,
        }

        {
          **timeframe_preamble(tf, unknown),
          **merged_note(sensors, sensor),
          **retired_sort_note(sort),
          **pending,
          period:,
          order:,
          limit: effective,
          **limit_note(limit, effective, definitions.size),
          results: definitions.map { |definition| rank(definition, options) },
        }
      end

      # `sort` used to choose between a value ranking and a chronological list,
      # and get_periods answers the second question now. The schema no longer
      # offers the argument, but a client works from the schema it cached, and
      # ignoring the argument in silence hands it a ranking where it asked for
      # a curve - the one answer that looks right and is not. Answered rather
      # than rejected: the ranking it gets is a real one, and the note is what
      # tells it where the other question went.
      def self.retired_sort_note(sort)
        return {} if sort.blank?

        {
          sort_note:
            '`sort` is no longer accepted and was ignored: get_ranking always ' \
              'orders by value. For the periods in date order, dense and ready ' \
              'to plot, call get_periods with the same timeframe and period.',
        }
      end
      private_class_method :retired_sort_note

      # `sensors` and `sensor` are two ways to name the same thing, and the
      # schema can only mark both optional. Filling both in is answerable - the
      # union is the only thing it can mean - so the call is not rejected over
      # a second round trip. But it is a mistake, and a silent one: a client
      # sending one name in each field and reading back two results cannot tell
      # whether the tool merged them or ignored one of the fields.
      def self.merged_note(sensors, sensor)
        return {} if Array(sensors).empty? || Array(sensor).empty?

        {
          sensors_note:
            'Both `sensors` and `sensor` were given. They were MERGED into ' \
              'one list (`sensors` first, a repeated name kept once), and ' \
              'nothing was dropped. Pass only one of the two.',
        }
      end
      private_class_method :merged_note

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
      # Shortening is right here - a top-10 cut to five is still a top-5 - but
      # doing it in silence is not: the list then reads as "there were only
      # five" rather than "the budget paid for five".
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
          **PeriodAxis.axis(rounded, options[:period]),
        }
      end
      private_class_method :rank
    end
  end
end
