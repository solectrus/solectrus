class Influx
  # Reads any measurement of the bucket, not only the configured sensors: the
  # raw data behind a technical diagnosis.
  #
  # The caller passes names and times, never Flux. Each name goes into the
  # program as an escaped string literal, so it can only ever be compared with,
  # and the program is built from read functions alone.
  class RawQuery
    # The fields of one measurement over a window, optionally narrowed to the
    # series whose tags match `tags`. Without `fields`, every field.
    Selection =
      Data.define(:measurement, :fields, :tags, :start, :stop) do
        def initialize(measurement:, start:, stop:, fields: nil, tags: {})
          super
        end

        def span = stop - start
      end
    public_constant :Selection

    # The aggregations a window can take. Flux runs mean/min/max only on
    # numbers: on a boolean or a string column the storage engine panics.
    # last and count take every type.
    AGGREGATIONS = %i[last mean min max count].freeze
    public_constant :AGGREGATIONS

    extend Rows
    include Flags

    # Columns the same in every row, or named by the request already
    DROP = 'drop(columns: ["_start", "_stop", "_measurement"])'.freeze
    private_constant :DROP

    # A string literal of Flux. The backslash and the quote end or change a
    # literal, and "${" starts an interpolation.
    def self.literal(value)
      escaped = value.to_s.gsub(/[\\"]/) { "\\#{it}" }.gsub('${', '\${')
      %("#{escaped}")
    end

    # `timeout` holds for all queries of this object together
    def initialize(timeout: nil, max_bytes: nil)
      @deadline = clock + timeout if timeout
      @max_bytes = max_bytes
    end

    # { measurement => [field, ...] } of the data in the window. It reads the
    # newest sample of every series, which the storage engine finds without
    # a scan.
    #
    # Not schema.measurements: it reads the index, which ignores the window
    # and still holds the names of deleted data.
    #
    # One row per measurement and field leaves InfluxDB, not one per series:
    # a bucket with many tag values would otherwise send all of them.
    def fields(start:, stop:)
      rows = run(<<~FLUX)
        from(bucket: #{bucket})
          |> range(start: #{time(start)}, stop: #{time(stop)})
          |> last()
          |> keep(columns: ["_measurement", "_field"])
          |> group(columns: ["_measurement", "_field"])
          |> limit(n: 1)
          |> group()
      FLUX
      rows.group_by { it['_measurement'] }.transform_values { |field_rows| field_rows.pluck('_field').sort }
    end

    # The newest sample of every field in every series, with its type and its
    # tags. A storage-side aggregate, so it reads no samples into Flux.
    def latest(selection)
      run(stream(selection, 'last', 'last()'))
    end

    # [latest, counts]: #latest, and the number of samples per series and
    # field, in one round trip
    def latest_and_counts(selection)
      rows = run([stream(selection, 'last', 'last()'), stream(selection, 'count', 'count()')].join("\n"))
      rows.partition { it['result'] == 'last' }
    end

    # The samples themselves, in time order per series and field
    def samples(selection)
      run(stream(selection, 'samples', DROP))
    end

    # The first sample of each series and field in the window, and every
    # sample whose value differs from the one before - the times a flag
    # switches or a mode changes. At most `limit` rows per series and field.
    #
    # Flux can subtract numbers only, so each value is mapped to a number
    # first and `_value` stays as it is. A string field is numbered by its
    # values in the window, at most `max_states` of them (TooManyStates).
    # This reads every sample into Flux: no storage-side aggregate tells
    # whether a value changed.
    def changes(selection, types:, limit:, max_states:)
      numbers, booleans, strings = by_kind(selection, types, :changes)
      states = strings.any? ? distinct_values(selection.with(fields: strings), max_states + 1) : {}
      many = states.select { |_, values| values.size > max_states }.keys
      raise TooManyStates, many if many.any?

      streams = [
        change_stream(selection.with(fields: numbers), 'numbers', 'float(v: r._value)', limit),
        change_stream(selection.with(fields: booleans), 'flags', 'if r._value then 1.0 else 0.0', limit),
        change_stream(selection.with(fields: strings), 'strings', state_number(states), limit),
      ]

      run(streams.compact.join("\n"))
    end

    # One value per window of `every` seconds and field, at the start of the
    # window. Windows without a sample are left out, except for "count": it
    # gives them as 0, so a gap in the data shows.
    #
    # The windows align to UTC. A window cut on the local timezone (option
    # location, or an offset) is not pushed down to the storage engine, so
    # Flux reads every sample: one field over a year in 1-day windows takes
    # longer than 8 s, against 0.2 s aligned to UTC.
    #
    # `types` are those of #latest, see .split: booleans are counted as 0 and
    # 1 for mean/min/max, so "max" says whether a flag was set at all.
    # Strings take the last value, the one aggregation that applies to text.
    def windows(selection, every:, function:, types:)
      raise ArgumentError, "Unknown aggregation: #{function}" if AGGREGATIONS.exclude?(function)

      numbers, booleans, strings = by_kind(selection, types, function)
      flags = selection.with(fields: booleans)
      streams = [
        window_stream(selection.with(fields: numbers), 'numbers', every:, function:, empty: function == :count),
        window_stream(flags, Flags::SAMPLES, every:, function: :count),
        window_stream(flags, Flags::TRUES, every:, function: :count, filter: 'filter(fn: (r) => r._value == true)'),
        window_stream(selection.with(fields: strings), 'strings', every:, function: :last),
      ]

      rows = run(streams.compact.join("\n"))
      counts, rows = rows.partition { Flags::STREAMS.include?(it['result']) }
      rows + flags_from(counts, function)
    end

    private

    # [numbers, booleans, strings] among the fields of the selection, see .split
    def by_kind(selection, types, function)
      booleans, strings = self.class.split(types.slice(*selection.fields), function)
      [selection.fields - booleans - strings, booleans, strings]
    end

    # The values each field takes in the window, { field => [value, ...] }.
    # At most `limit` per series and field: a free text has as many values as
    # samples, and the caller only needs to know that there are too many.
    def distinct_values(selection, limit)
      rows = run(stream(selection, 'distinct', 'distinct()', "limit(n: #{limit.to_i})", 'keep(columns: ["_field", "_value"])'))
      rows.group_by { it['_field'] }.transform_values { |field_rows| field_rows.pluck('_value').uniq.sort }
    end

    def change_stream(selection, name, number, limit)
      return if selection.fields.empty?

      stream(
        selection,
        name,
        "map(fn: (r) => ({r with n: #{number}}))",
        'difference(columns: ["n"], keepFirst: true)',
        'filter(fn: (r) => not exists r.n or r.n != 0.0)',
        'drop(columns: ["n"])',
        DROP,
        "limit(n: #{limit.to_i})",
      )
    end

    # A number per field and value, the field compared first so a sample
    # passes the values of its own field only. A value that arrived after
    # #distinct_values counts as 0, so its arrival still shows as a change.
    def state_number(states)
      index = 0
      branches =
        states.map do |field, values|
          numbered = values.map { "if r._value == #{self.class.literal(it)} then #{index += 1}.0 else " }.join
          "if r._field == #{self.class.literal(field)} then (#{numbered}0.0) else "
        end

      "#{branches.join}0.0"
    end

    def window_stream(selection, name, every:, function:, filter: nil, empty: false)
      return if selection.fields.empty?

      steps = [
        *filter,
        "aggregateWindow(every: #{every.to_i}s, fn: #{function}, createEmpty: #{empty}, timeSrc: \"_start\")",
        DROP,
      ]
      stream(selection, name, *steps)
    end

    def stream(selection, name, *steps)
      [source(selection), *steps.map { "  |> #{it}" }, "  |> yield(name: \"#{name}\")"].join("\n")
    end

    def source(selection)
      "from(bucket: #{bucket})\n  |> range(start: #{time(selection.start)}, stop: #{time(selection.stop)})\n  " \
        "|> filter(fn: #{predicate(selection)})"
    end

    def predicate(selection)
      conditions = ["r._measurement == #{self.class.literal(selection.measurement)}"]

      if selection.fields
        fields = selection.fields.map { "r._field == #{self.class.literal(it)}" }
        conditions << "(#{fields.join(' or ')})"
      end

      selection.tags.each do |key, value|
        conditions << "r[#{self.class.literal(key)}] == #{self.class.literal(value)}"
      end

      "(r) => #{conditions.join(' and ')}"
    end

    def time(value) = value.utc.iso8601(9)

    def bucket = self.class.literal(Rails.configuration.x.influx.bucket)

    # The event names no query: the program can hold values of the data,
    # which stay out of the log
    def run(flux)
      ActiveSupport::Notifications.instrument('query.sensor_influx', class: self.class.name) do
        Influx.query(flux, timeout: (@deadline - clock if @deadline), max_bytes: @max_bytes)
      end
    end

    def clock = Process.clock_gettime(Process::CLOCK_MONOTONIC)
  end
end
