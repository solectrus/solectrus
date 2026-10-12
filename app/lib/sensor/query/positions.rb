module Sensor
  module Query
    # The positions of a car in a period, from its latitude and its longitude,
    # as segments: a car stays at a position until the next change.
    #
    # A parked car repeats its position, so InfluxDB returns only the readings
    # that change the position, and the first reading. A year gives about a
    # thousand changes. The position is a state (see the DSL `state`): it
    # holds until the next reading, at any age. So the last reading before
    # the period gives the position at its start, and the last position lasts
    # until the end of the period. A source that sends a position only when
    # it changes, like TeslaMate, thus gives a whole night at home.
    #
    # A source can also stop to send the position while the car drives on.
    # The odometer of the car ends a position therefore: when it rises by
    # more than MOVE after the reading of the position, the car left the
    # position at the time of this odometer reading.
    #
    # Each segment knows the time between its first reading and the reading
    # before it (`gap`), so a caller sees how often the car reported at that
    # time. The first reading of the query has no gap.
    class Positions < Helpers::Influx::Base
      Segment = ::Data.define(:from, :to, :latitude, :longitude, :gap) do
        def duration = to - from
      end
      public_constant :Segment

      # The rise of the odometer after a position that tells that the car left
      # it (km). The last reading of a drive can come shortly after the
      # position of the arrival, so a small rise is no departure.
      MOVE = 1
      public_constant :MOVE

      # Whether the odometer tells that the car left a position, from the
      # odometer at the position and a later one
      def self.left?(at_position, later) = later > at_position + MOVE

      # The odometer at a time, from the last reading up to it, at any age.
      # The query stays cached (see Sensor::Query::LastSeen).
      def self.odometer_at(odometer, time)
        Sensor::Query::LastSeen.new([odometer], before: time + 1.second).readings[odometer]&.to_f
      end

      # `period` is a range of times, `odometer` the sensor of the odometer of
      # the car, or nil
      def initialize(latitude:, longitude:, period:, odometer: nil)
        super([latitude, longitude], Timeframe.new('all'))
        @latitude = latitude
        @longitude = longitude
        @odometer = odometer if odometer && Sensor::Config.configured?(odometer)
        @from = period.begin
        @to = [period.end, Time.current].min
      end

      # The segments in the order of time, cut to the period
      def call
        return [] unless available_sensors.size == 2 && from < to

        rows = query(build_flux_query).group_by { it['result'] }
        segments(readings(rows), odometer_readings(rows))
      end

      # The column of the time since the reading before
      GAP = 'gap'.freeze
      private_constant :GAP

      # A reading: its time, its position and the seconds since the reading
      # before it
      Reading = ::Data.define(:time, :latitude, :longitude, :gap)
      private_constant :Reading

      private

      attr_reader :latitude, :longitude, :odometer, :from, :to

      # The last reading before the period, the first reading in it and the
      # changes after it, each with a new position. elapsed() drops the first
      # reading of the period, so the query gives it on its own, and its gap
      # comes from the reading before the period.
      def readings(rows)
        before = rows['before']&.first&.then { reading(it) }
        first = rows['first']&.first&.then { reading(it, before:) }
        changes = rows.fetch('changes', []).sort_by { it['_time'] }.map { reading(it) }

        [before, first, *changes].compact.chunk_while { |a, b| position(a) == position(b) }.map(&:first)
      end

      def reading(row, before: nil)
        time = Time.zone.parse(row['_time'])
        gap = before ? time - before.time : row[GAP]&.fdiv(1_000_000_000)

        Reading.new(time:, latitude: row[column(latitude)], longitude: row[column(longitude)], gap:)
      end

      # [[Time, km], ...] of the odometer, from its last reading before the
      # period, in the order of time. The odometer gives a row for each
      # reading, and Time.iso8601 is many times faster than Time.zone.parse.
      def odometer_readings(rows)
        [*rows['odometer_before'], *rows['odometer']]
          .map { [Time.iso8601(it['_time']), it['_value'].to_f] }
          .sort_by(&:first)
      end

      def position(reading) = [reading.latitude, reading.longitude]

      def segments(readings, odometer_readings)
        ends = [*readings.drop(1).map(&:time), to]

        readings.zip(ends).filter_map do |reading, ending|
          ending = [ending, departure(reading.time, odometer_readings)].compact.min
          start = [reading.time, from].max
          next if start >= ending

          Segment.new(from: start, to: ending, latitude: reading.latitude, longitude: reading.longitude, gap: reading.gap)
        end
      end

      # The time of the first odometer reading that is more than MOVE above
      # the odometer at the time of the position, or nil
      def departure(time, odometer_readings)
        return unless odometer

        after = first_after(time, odometer_readings)
        at_position = odometer_at(time, odometer_readings, after)
        return unless at_position

        odometer_readings[after..].find { |_, km| self.class.left?(at_position, km) }&.first&.in_time_zone
      end

      # The odometer at a time, from the last reading up to it. A position
      # before the period can be older than each odometer reading of the
      # query, so its odometer comes from one more query.
      def odometer_at(time, odometer_readings, after)
        reading = odometer_readings[after - 1] if after.positive?
        reading&.last || self.class.odometer_at(odometer, time)
      end

      # The index of the first odometer reading after the time. The readings
      # are in the order of time, so a binary search finds it.
      def first_after(time, odometer_readings)
        odometer_readings.bsearch_index { |reading_time, _| reading_time > time } || odometer_readings.size
      end

      # The build of the summaries reads each day once, so a cache would only
      # fill the memory
      def cache_options(**) = nil

      # The pivot names a column after the measurement and the field, so the
      # two sensors can come from different measurements.
      def column(sensor_name)
        "#{Sensor::Config.measurement(sensor_name)}_#{Sensor::Config.field(sensor_name)}"
      end

      # The rows of the result "changes" are the readings with a new position.
      # The column GAP of a change holds the nanoseconds since the reading
      # before it. elapsed() is native, and a map() for the time of each
      # reading was more than twice as slow (a year: 400 -> 1050 ms). The row
      # of the result "first" is the first reading of the period, and the row
      # of "before" the last reading before it. last() reads only the edge of
      # its range, so the reading before needs no limit. The odometer gives
      # its last reading before the period and the readings of the period that
      # change it. A parked car repeats its odometer, and the first reading of
      # each value gives the same departure (a week: 491 -> 21 rows, 68 -> 54
      # ms, a year: 34482 -> 1329 rows, 484 -> 386 ms).
      def build_flux_query
        lat = column(latitude)
        lon = column(longitude)

        <<~FLUX
          pair = (tables=<-) => tables
            |> group()
            |> pivot(rowKey: ["_time"], columnKey: ["_measurement", "_field"], valueColumn: "_value")
            |> filter(fn: (r) => exists r["#{lat}"] and exists r["#{lon}"])
            |> keep(columns: ["_time", "#{lat}", "#{lon}"])

          #{from_bucket}
            |> #{range(start: installation_time, stop: from)}
            |> #{filter}
            |> last()
            |> pair()
            |> yield(name: "before")

          data = #{from_bucket}
            |> #{range(start: from, stop: to)}
            |> #{filter}
            |> pair()

          data
            |> elapsed(unit: 1ns, columnName: "#{GAP}")
            |> duplicate(column: "#{lat}", as: "dlat")
            |> duplicate(column: "#{lon}", as: "dlon")
            |> difference(columns: ["dlat", "dlon"], keepFirst: true)
            |> filter(fn: (r) => not exists r.dlat or r.dlat != 0.0 or r.dlon != 0.0)
            |> keep(columns: ["_time", "#{lat}", "#{lon}", "#{GAP}"])
            |> yield(name: "changes")

          data
            |> first(column: "#{lat}")
            |> yield(name: "first")
          #{odometer_flux}
        FLUX
      end

      def odometer_flux
        return '' unless odometer

        <<~FLUX
          #{from_bucket}
            |> #{range(start: installation_time, stop: from)}
            |> #{filter(selected_sensors: [odometer])}
            |> last()
            |> keep(columns: ["_time", "_value"])
            |> yield(name: "odometer_before")

          #{from_bucket}
            |> #{range(start: from, stop: to)}
            |> #{filter(selected_sensors: [odometer])}
            |> duplicate(column: "_value", as: "step")
            |> difference(columns: ["step"], keepFirst: true)
            |> filter(fn: (r) => not exists r.step or r.step != 0.0)
            |> keep(columns: ["_time", "_value"])
            |> yield(name: "odometer")
        FLUX
      end

      def installation_time = Helpers::Influx::FluxProgram.installation_time
    end
  end
end
