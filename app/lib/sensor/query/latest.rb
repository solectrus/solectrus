module Sensor
  module Query
    # Fetches the latest/current values for sensors directly from InfluxDB
    # Used for: Dashboard live data, current sensor readings
    class Latest < Helpers::Influx::Base
      # The age of a current reading at most. An older reading is no current
      # value anymore, for example of a collector that stopped. A state holds
      # at any age (see the DSL `state`).
      MAX_AGE = 15.minutes
      public_constant :MAX_AGE

      def initialize(sensor_names)
        super(sensor_names, Timeframe.now)
      end

      protected

      def fetch_raw_data
        super.tap do |raw_data|
          # Feed the freshness of the just-fetched value into the adaptive
          # poll-interval estimator. `:time` is the timestamp of the newest
          # data point, so its age tells us how often InfluxDB is updated.
          Influx::PollInterval.record(raw_data[:time])

          add_older_states!(raw_data)
          drop_stale_values!(raw_data)
        end
      end

      def create_data_instance(raw_data, timeframe)
        # Pass the per-sensor timestamps through (including those of values just
        # dropped as stale), so callers can report freshness and distinguish a
        # stale reading from a sensor that never reported. The snapshot `time`
        # is derived from these (their newest value).
        Sensor::Data::Single.new(
          raw_data[:payload],
          timeframe:,
          times: raw_data[:times],
        )
      end

      private

      # A state holds until its next reading, at any age (see the DSL
      # `state`). The query looks back a day, so a state without a reading in
      # this day comes from the whole history (see Sensor::Query::LastSeen).
      # Only a new reading can change it, and the query of the day finds such
      # a reading first. So the search of the history ends at midnight, which
      # keeps its result cached for the whole day.
      #
      # An older reading only fills a gap. A calculated state has no reading
      # of its own, so the search reads its inputs, too, and their readings of
      # this day must stay.
      def add_older_states!(raw_data)
        missing = available_sensors.select { Sensor::Registry[it].state? && !raw_data[:payload].key?(it) }
        return if missing.empty?

        older = Sensor::Query::LastSeen.new(missing, before: Time.current.beginning_of_day).readings
        raw_data[:payload].reverse_merge!(older.except(:time, :times))
        raw_data[:times].reverse_merge!(older[:times])
      end

      # Drop sensor values whose timestamp is older than MAX_AGE.
      # The Flux `last()` returns the most recent point within the 1-day range
      # regardless of how old it is, so without this filter the dashboard
      # would keep showing the last seen value indefinitely after a data
      # source goes offline. A state never goes stale.
      def drop_stale_values!(raw_data)
        times = raw_data[:times] || {}
        now = Time.current

        raw_data[:payload].delete_if do |sensor_name, _value|
          time = times[sensor_name]
          next false if time.nil? || Sensor::Registry[sensor_name].state?

          (now - time) > MAX_AGE
        end
      end

      def build_flux_query
        <<~FLUX
          #{from_bucket}
          |> #{range(start: 1.day.ago)}
          |> #{filter}
          |> last()
        FLUX
      end
    end
  end
end
