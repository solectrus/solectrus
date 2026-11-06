module McpServer
  module Tools
    # The samples of any InfluxDB measurement, not only of the configured
    # sensors: also the other measurements in the same bucket, as the raw
    # data of a technical diagnosis.
    #
    # Each field keeps its own time axis. Devices write their fields at their
    # own moments, and a shared axis would either invent values between two
    # samples or put two values side by side that were never measured
    # together.
    class RawSeries < Base
      tool_name 'get_raw_series'
      title 'Get raw InfluxDB samples of a measurement'

      MAX_FIELDS = 10
      # Distinct tag sets. More are a sign of an ID in a tag, which `tags`
      # narrows.
      MAX_SERIES = 20
      # Over the whole response, as in get_series: what the client pays for
      # in its context. A point costs ~12 bytes, its value and its time.
      MAX_POINTS = 3000
      # Every sample is counted before it is read, and the count reads the
      # whole window as well
      MAX_RAW_SPAN = 7.days
      # "changes" reads every sample into Flux, about 300,000 a second on a
      # server and far fewer on a small computer. The samples are counted
      # first, in the storage engine, so a larger request never reaches Flux.
      MAX_CHANGES_SAMPLES = 50_000
      MAX_CHANGES_SPAN = 31.days
      MAX_SPAN = 366.days
      MAX_TAGS = 5
      # Values of a string field that "changes" numbers. More are no states.
      MAX_STATES = 50
      public_constant :MAX_FIELDS, :MAX_SERIES, :MAX_POINTS, :MAX_TAGS, :MAX_STATES, :MAX_CHANGES_SAMPLES
      public_constant :MAX_RAW_SPAN, :MAX_CHANGES_SPAN, :MAX_SPAN

      AGGREGATIONS = ['none', 'changes', *Influx::RawQuery::AGGREGATIONS.map(&:to_s)].freeze
      private_constant :AGGREGATIONS

      TIME_AXIS = 't[i] = seconds after `start` of values[i], per field'.freeze
      CHANGES_NOTE =
        'Only the first sample and every change. A value holds until the next entry ' \
          'while the device kept writing: a gap in the data does not show here.'.freeze
      private_constant :TIME_AXIS, :CHANGES_NOTE

      description <<~TEXT.strip
        Raw InfluxDB samples of one measurement, for data that NO sensor
        reads. Only a measurement and fields that list_measurements returned -
        never guess them. A sensor name (inverter_power, house_power, ...) is
        no measurement: its curve, also at an exact time, is get_series.

        Window: `start`/`stop` (ISO 8601, stop default now) or `timeframe`.
        aggregation "none" returns every sample, over at most
        #{MAX_RAW_SPAN.in_days.to_i} days; "last"/"mean"/"min"/"max"/"count" one
        value per `resolution` window (default: the finest that fits), over at
        most #{MAX_SPAN.in_days.to_i} days. At most
        #{MAX_POINTS} points: a larger request is REJECTED, never cut, and the
        error says what fits. Booleans aggregate as 0/1 (max 1 = true at least
        once); strings take the last value. "count": samples per window, 0
        included, so a gap shows, even inside a window. "changes"
        returns the first sample and every change of value, over at most
        #{MAX_CHANGES_SPAN.in_days.to_i} days: when a flag switched, a mode
        changed.

        Per series (`tags`) and field its own axis: `t[i]` = seconds after
        `start` of `values[i]`, the window START if aggregated. Fields are NOT
        aligned: pair them by `t`, never by index. Between two samples the
        value is unknown; other empty windows are left out. A number field states
        its `max` and `min` with their time `at`, so a "when was it highest?"
        needs no counting.
      TEXT
      input_schema(
        properties: {
          measurement: { type: 'string', description: 'Exact name, see list_measurements.' },
          fields: {
            type: 'array',
            items: { type: 'string' },
            minItems: 1,
            maxItems: MAX_FIELDS,
          },
          tags: {
            type: 'object',
            additionalProperties: { type: 'string' },
            maxProperties: MAX_TAGS,
            description: 'Only the series with these tag values, e.g. {"device": "a"}.',
          },
          start: { type: 'string', description: 'e.g. "2026-01-11T04:30:00Z"; without offset local time.' },
          stop: { type: 'string' },
          timeframe: timeframe_property('Instead of start/stop, e.g. "P24H".'),
          aggregation: { type: 'string', enum: AGGREGATIONS, default: 'none' },
          resolution: { type: 'string', enum: Resolution::LABELS, description: 'Only with an aggregation.' },
        },
        required: %w[measurement fields],
      )
      read_only idempotent: true

      # The admin allows raw data in the settings, see McpServer::RawData
      def self.available? = RawData.enabled?

      def self.around_perform(&) = RawData.session(&)

      def self.perform( # rubocop:disable Metrics/ParameterLists
        measurement:,
        fields:,
        aggregation: 'none',
        resolution: nil,
        tags: nil,
        timeframe: nil,
        start: nil,
        stop: nil,
        **
      )
        validate_choices!(aggregation, resolution)
        tf = parse_timeframe(timeframe) if timeframe.present?
        selection = selection_for(measurement, fields, tags, *Window.for(start:, stop:, timeframe: tf))
        function = aggregation_for(aggregation, resolution, selection)

        # Only what reads samples needs counting: the windows follow from the span
        counted = function.nil? || function == :changes
        latest, counts = RawData.read { counted ? it.latest_and_counts(selection) : [it.latest(selection), []] }
        enforce_series!(RawData.series(latest))

        types = Influx::RawQuery.types(latest)
        enforce_no_sensor!(selection.measurement) if types.empty?
        missing = selection.fields - types.keys
        selection = selection.with(fields: selection.fields & types.keys)

        rows, label = selection.fields.empty? ? [[], resolution] : read(selection, function, resolution, latest, counts, types)

        respond(selection, function, label, rows, types, missing)
      end

      # A model asked with "the PV power at noon" sent the sensor name as
      # the measurement (bin/llm-test, cases/raw.yml). Without data under that
      # name, it learns where the sensor is answered instead of what is
      # missing.
      def self.enforce_no_sensor!(measurement)
        sensor = McpServer::Sensors.all.find { it.name.to_s == measurement }
        return unless sensor

        others = McpServer::SupportedTools.alternatives(sensor)
        instead = others.empty? ? 'No tool answers for it.' : "Ask #{tool_list(others)} instead."
        raise ArgumentError, "#{measurement} is a sensor, not a measurement. #{instead}"
      end
      private_class_method :enforce_no_sensor!

      def self.read(selection, function, resolution, latest, counts, types)
        case function
        when nil then read_samples(selection, counts, latest.size)
        when :changes then read_changes(selection, counts, types)
        else read_windows(selection, function, resolution, latest.size, types)
        end
      end
      private_class_method :read

      def self.respond(selection, function, label, rows, types, missing)
        # What Influx::RawQuery#windows did to booleans and strings
        windowed = Influx::RawQuery::AGGREGATIONS.include?(function)
        booleans, strings = windowed ? Influx::RawQuery.split(types, function) : [[], []]
        # A count is a number, whatever it counts
        value_types = function == :count ? types.transform_values { %w[integer] } : types

        {
          measurement: selection.measurement,
          start: selection.start.iso8601,
          stop: selection.stop.iso8601,
          tags: selection.tags.presence,
          aggregation: function&.to_s || 'none',
          resolution: label,
          point_count: rows.size,
          time_axis: TIME_AXIS,
          changes_note: (CHANGES_NOTE if function == :changes),
          series: series(selection, rows, value_types, strings),
          **notes(missing, booleans),
        }.compact
      end
      private_class_method :respond

      def self.selection_for(measurement, fields, tags, start, stop)
        measurement = RawData.name!(measurement, 'measurement')
        fields = Array(fields).map { RawData.name!(it, 'field') }.uniq
        raise ArgumentError, 'Give at least one field in `fields`.' if fields.empty?
        raise ArgumentError, "Too many fields (max #{MAX_FIELDS})." if fields.size > MAX_FIELDS

        withheld = fields & RawData.withheld(measurement)
        if withheld.any?
          raise ArgumentError,
                "#{withheld.join(', ')}: personal data that only the admin sees, " \
                  'which MCP does not offer. Ask without these fields.'
        end

        Influx::RawQuery::Selection.new(measurement:, fields:, tags: tags_for(tags), start:, stop:)
      end
      private_class_method :selection_for

      def self.tags_for(tags)
        return {} if tags.blank?
        raise ArgumentError, '`tags` must be an object of tag names and values.' unless tags.is_a?(Hash)
        raise ArgumentError, "Too many tags (max #{MAX_TAGS})." if tags.size > MAX_TAGS

        tags.to_h do |key, value|
          key = RawData.name!(key, 'tag name')
          raise ArgumentError, "Invalid tag name: #{key.inspect}. Names starting with _ are no tags." if key.start_with?('_')
          raise ArgumentError, "Invalid value of tag #{key}: give a string." unless value.is_a?(String)

          [key, RawData.name!(value, "value of tag #{key}")]
        end
      end
      private_class_method :tags_for

      # The schema states both sets, this is the backstop
      def self.validate_choices!(aggregation, resolution)
        raise ArgumentError, "Invalid aggregation: #{aggregation.inspect}." if AGGREGATIONS.exclude?(aggregation.to_s)
        raise ArgumentError, "Invalid resolution: #{resolution.inspect}." if resolution && Resolution::LABELS.exclude?(resolution)
      end
      private_class_method :validate_choices!

      # The Flux aggregation, nil for the samples themselves
      def self.aggregation_for(aggregation, resolution, selection)
        limit, message =
          case aggregation.to_s
          when 'none'
            raise ArgumentError, '`resolution` needs an aggregation ("last", "mean", "min" or "max").' if resolution

            [MAX_RAW_SPAN, 'Ask a shorter one, or aggregate: "changes" gives when a flag switched, "max" per window whether it was set.']
          when 'changes'
            raise ArgumentError, '"changes" takes no `resolution`: it returns the samples where a value changed.' if resolution

            [MAX_CHANGES_SPAN, '"changes" reads every sample. Ask a shorter one, or "max" of a flag per window.']
          else
            [MAX_SPAN, nil]
          end
        enforce_span!(selection, limit, message)

        aggregation.to_sym unless aggregation.to_s == 'none'
      end
      private_class_method :aggregation_for

      def self.enforce_span!(selection, limit, advice)
        return if selection.span <= limit

        raise ArgumentError,
              ["The window spans at most #{limit.in_days.to_i} days; this one #{(selection.span / 1.day).ceil}.", advice].compact.join(' ')
      end
      private_class_method :enforce_span!

      def self.enforce_series!(series)
        return if series.size <= MAX_SERIES

        keys = series.flat_map(&:keys).uniq.join(', ')
        raise ArgumentError,
              "These fields come in #{series.size} series (max #{MAX_SERIES}). " \
                "Narrow them with `tags` (tag names: #{keys}); list_measurements gives their values."
      end
      private_class_method :enforce_series!

      def self.read_samples(selection, counts, tables)
        total = counts.sum { it['_value'].to_i }
        raise ArgumentError, too_many_samples(selection, total, tables) if total > MAX_POINTS

        [RawData.read { it.samples(selection) }, nil]
      end
      private_class_method :read_samples

      def self.too_many_samples(selection, total, tables)
        minutes = (selection.span * MAX_POINTS / total / 60).floor
        finest = Resolution.finest(selection.span, tables)

        "The window holds #{total} samples of these fields, more than #{MAX_POINTS}. " \
          "Shorten it to about #{minutes} minutes, or ask fewer fields" +
          (finest ? ", or aggregate (resolution \"#{finest}\" fits)." : '.')
      end
      private_class_method :too_many_samples

      def self.read_windows(selection, function, resolution, tables, types)
        every, label = Resolution.for(resolution, selection.span, tables)
        rows = RawData.read { it.windows(selection, every:, function:, types:) }

        [rows, label]
      end
      private_class_method :read_windows

      # The changes are counted only once they are read, so the budget is a
      # limit per series and field in the query, and a response over it fails
      def self.read_changes(selection, counts, types)
        total = counts.sum { it['_value'].to_i }
        raise ArgumentError, too_many_for_changes(selection, total) if total > MAX_CHANGES_SAMPLES

        rows = RawData.read { it.changes(selection, types:, limit: MAX_POINTS + 1, max_states: MAX_STATES) }
        if rows.size > MAX_POINTS
          raise ArgumentError,
                "These fields change more than #{MAX_POINTS} times in the window, nearly at every " \
                  'sample. Ask "changes" of state fields alone, a shorter window, or aggregate per window.'
        end

        [rows, nil]
      rescue Influx::RawQuery::TooManyStates => e
        raise ArgumentError,
              "#{e.fields.join(', ')}: more than #{MAX_STATES} different values, too many for " \
                '"changes". Ask them without aggregation, or with "last" per window.'
      end
      private_class_method :read_changes

      # Names a window that fits: a model told "shorter" only shortened from a
      # year to a month, twelve times over (bin/llm-test live run). An outage
      # was what it looked for, and "count" finds one over a whole year.
      def self.too_many_for_changes(selection, total)
        seconds = selection.span * MAX_CHANGES_SAMPLES / total
        fits =
          if seconds >= 2.days then "#{(seconds / 1.day).floor} days"
          elsif seconds >= 2.hours then "#{(seconds / 1.hour).floor} hours"
          else "#{[(seconds / 60).floor, 1].max} minutes"
          end

        "\"changes\" reads every sample, and the window holds #{total} samples of these fields, " \
          "more than #{MAX_CHANGES_SAMPLES}. Shorten it to about #{fits}, or ask fewer fields. " \
          "An outage or a gap in the data shows with \"count\" per window, over up to #{MAX_SPAN.in_days.to_i} days."
      end
      private_class_method :too_many_for_changes

      # `last_instead` are the fields that took the last value rather than the
      # aggregation asked for.
      #
      # The rows of one Flux table share their tags and arrive together, so
      # the tags are read once per table. A time repeats across fields and
      # series, so each is parsed once.
      def self.series(selection, rows, types, last_instead)
        start = selection.start.utc
        offsets = Hash.new { |cache, time| cache[time] = offset(time, start) }
        tables = rows.chunk_while { |row, next_row| row.values_at('result', 'table') == next_row.values_at('result', 'table') }

        tables.group_by { Influx::RawQuery.tags_of(it.first) }.sort_by { |tags, _| tags.to_a }.map do |tags, series_tables|
          by_field = series_tables.flatten(1).group_by { it['_field'] }
          fields =
            by_field.slice(*selection.fields).to_h do |field, field_rows|
              [field, field_entry(field_rows, types[field], offsets, last: last_instead.include?(field))]
            end

          { tags: tags.presence, fields: }.compact
        end
      end
      private_class_method :series

      def self.field_entry(rows, types, offsets, last:)
        {
          type: types.join('|'),
          aggregation: ('last' if last),
          **extremes(rows, types),
          t: rows.map { offsets[it['_time']] },
          values: rows.map { RawData.compact(it['_value']) },
        }.compact
      end
      private_class_method :field_entry

      # The highest and the lowest value of a number field, each with its time
      # (the first, where it repeats). Read off `t` instead, a model named the
      # right value at the wrong hour (bin/llm-test, cases/raw.yml): the time
      # of a maximum needs the index of it in `values` and the sum of `start`
      # and its offset, two steps that each go wrong. get_series states its
      # `peak` for the same reason.
      def self.extremes(rows, types)
        return {} unless types.all? { %w[float integer].include?(it) }

        min, max = rows.minmax_by { it['_value'] }
        { max: extreme(max), min: extreme(min) }
      end
      private_class_method :extremes

      def self.extreme(row) = { at: Time.zone.parse(row['_time']).iso8601, value: RawData.compact(row['_value']) }
      private_class_method :extreme

      def self.offset(time, start)
        seconds = (Time.iso8601(time) - start).round(3)
        seconds == seconds.to_i ? seconds.to_i : seconds
      end
      private_class_method :offset

      # `booleans` are those counted as 0/1
      def self.notes(missing, booleans)
        notes = {}
        if missing.any?
          notes[:missing_fields] = missing
          notes[:missing_note] =
            'No sample in this window: nothing was written, or the name is wrong. list_measurements gives the names.'
        end

        if booleans.any?
          notes[:boolean_note] = 'Booleans as 0/1: max 1 = true at least once in the window, mean = share of samples true.'
        end

        notes
      end
      private_class_method :notes
    end
  end
end
