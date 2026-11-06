module McpServer
  module Tools
    # The raw structure of InfluxDB: which measurements hold data, and which
    # fields and tags one of them carries. It is the discovery step of
    # get_raw_series, as list_sensors is the one of the sensor tools.
    class ListMeasurements < Base
      tool_name 'list_measurements'
      title 'List the raw InfluxDB measurements and their fields'

      DEFAULT_LOOKBACK_DAYS = RawData::LOOKBACK.in_days.to_i
      MAX_LOOKBACK_DAYS = 366
      public_constant :DEFAULT_LOOKBACK_DAYS, :MAX_LOOKBACK_DAYS

      # More names than this are a sign of a bucket shared with other
      # software, and `query` narrows them
      MAX_MEASUREMENTS = 200
      public_constant :MAX_MEASUREMENTS

      # Per tag. A tag with more values is an ID rather than a category.
      MAX_TAG_VALUES = 20
      private_constant :MAX_TAG_VALUES

      # Found here, a device still sent a model searching list_sensors for a
      # sensor of each of its values (bin/llm-test, cases/raw.yml)
      NO_SENSOR_NOTE = 'No sensor reads these fields, so get_raw_series is the way to their data.'.freeze
      private_constant :NO_SENSOR_NOTE

      description <<~TEXT.strip
        Raw InfluxDB structure, for diagnosis beyond the configured sensors:
        also the other measurements in the same bucket. Without
        `measurement`: the measurements written within the lookback. With it,
        or with a `query` that matches one: its fields (type, newest value and
        time, `sensor` where a sensor reads it - prefer the sensor tools then)
        and tag values. Then call get_raw_series.
      TEXT
      input_schema(
        properties: {
          query: { type: 'string', description: 'Part of a measurement or field name, any case.' },
          measurement: { type: 'string', description: 'Exact name, for its fields and tags.' },
          lookback_days: {
            type: 'integer',
            minimum: 1,
            maximum: MAX_LOOKBACK_DAYS,
            default: DEFAULT_LOOKBACK_DAYS,
          },
        },
      )
      read_only idempotent: false

      # The admin allows raw data in the settings, see McpServer::RawData
      def self.available? = RawData.enabled?

      def self.around_perform(&) = RawData.session(&)

      def self.perform(query: nil, measurement: nil, lookback_days: DEFAULT_LOOKBACK_DAYS, **)
        days = lookback_days.to_i
        unless days.between?(1, MAX_LOOKBACK_DAYS)
          raise ArgumentError, "lookback_days must be between 1 and #{MAX_LOOKBACK_DAYS}."
        end

        stop = Time.current.change(usec: 0)
        start = stop - days.days

        answer = measurement.nil? ? measurements(query, start:, stop:) : details(RawData.name!(measurement, 'measurement'), start:, stop:)
        answer.merge(lookback_days: days)
      end

      def self.measurements(query, start:, stop:)
        fields = RawData.fields(start:, stop:)
        return search(query, fields, start:, stop:) if query.present?

        listing(fields.keys.sort)
      end
      private_class_method :measurements

      def self.listing(names, **extra)
        {
          measurement_count: names.size,
          measurements: names.first(MAX_MEASUREMENTS),
          **extra,
          **truncation_note(names.size),
        }
      end
      private_class_method :listing

      # A single match comes with its fields, which the next call would ask
      # for anyway. Without a match, every name comes along: a device is
      # written under a name of its own, which the brand or the type in a
      # question ("Shelly", "heat pump") need not contain.
      def self.search(query, fields, start:, stop:)
        matches = RawData.matches(fields, query)
        return details(matches.keys.first, start:, stop:) if matches.one?
        return listing(fields.keys.sort, note: no_match_note(query)) if matches.empty?

        listing(matches.keys, matching_fields: matches.compact_blank.presence).compact
      end
      private_class_method :search

      def self.no_match_note(query)
        "No measurement or field name contains \"#{query.to_s.strip}\". These are all the " \
          'measurements, named by their owner after what a device does (e.g. "Fridge"), ' \
          'not after its brand: look into those that can be meant. If none can, this ' \
          'instance holds no such data: say so, and answer the rest of the question in ' \
          'the same reply.'
      end
      private_class_method :no_match_note

      def self.truncation_note(count)
        return {} if count <= MAX_MEASUREMENTS

        { truncated_note: "Only the first #{MAX_MEASUREMENTS} of #{count} names. Narrow them with `query`." }
      end
      private_class_method :truncation_note

      def self.details(measurement, start:, stop:)
        selection = Influx::RawQuery::Selection.new(measurement:, start:, stop:)
        withheld = RawData.withheld(measurement)
        rows = RawData.read { it.latest(selection) }.reject { withheld.include?(it['_field']) }
        return { measurement:, fields: {}, note: empty_note(measurement) } if rows.empty?

        series = RawData.series(rows)
        fields = fields(measurement, rows)

        {
          measurement:,
          series_count: series.size,
          tags: tags(series),
          fields:,
          note: (NO_SENSOR_NOTE if fields.values.none? { it.key?(:sensor) }),
        }.compact_blank
      end
      private_class_method :details

      def self.empty_note(measurement)
        "No field of \"#{measurement}\" has data within the lookback. Check the " \
          'name with list_measurements without `measurement`, or widen lookback_days.'
      end
      private_class_method :empty_note

      # Per field the type and the newest sample over all series
      def self.fields(measurement, rows)
        sensors = McpServer::Sensors.by_field
        types = Influx::RawQuery.types(rows)

        rows.group_by { it['_field'] }.sort.to_h do |field, field_rows|
          newest = field_rows.max_by { it['_time'] }
          [
            field,
            {
              type: types[field].join('|'),
              last: RawData.compact(newest['_value']),
              last_at: Time.zone.parse(newest['_time']).iso8601,
              sensor: sensors[[measurement, field]],
            }.compact,
          ]
        end
      end
      private_class_method :fields

      def self.tags(series)
        values = Hash.new { |hash, key| hash[key] = Set.new }
        series.each { |tags| tags.each { |key, value| values[key] << value } }

        values.sort.to_h do |key, set|
          list = set.sort
          if list.size > MAX_TAG_VALUES
            [key, { value_count: list.size, values: list.first(MAX_TAG_VALUES) }]
          else
            [key, list]
          end
        end
      end
      private_class_method :tags
    end
  end
end
