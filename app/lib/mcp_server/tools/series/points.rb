module McpServer
  module Tools
    class Series < Base
      # Serialises one sensor's {time => value} hash into the point list a
      # client receives.
      module Points
        module_function

        # Sorted {time, value} points. An empty bucket is a point without a
        # value; dropping those is what makes a sporadically written sensor
        # affordable, and it stays unambiguous because the remaining points sit
        # on the same grid - a missing timestamp reads exactly like an explicit
        # null.
        def build(data, sensor_name, aggregation, unit:, include_nulls:, timeframe: nil)
          buckets = raw(data, sensor_name, aggregation) || {}
          buckets = buckets.compact unless include_nulls
          closing = closing_bucket(timeframe)

          buckets.sort.map! do |time, value|
            { time: normalize_time(time, closing), value: normalize_value(value, unit) }
          end
        end

        # `data` exposes an accessor for every requested sensor: raw sensors via
        # Data::Series, derived sensors via the singleton accessor that
        # process_calculated_sensors installs (house_power - sum(custom_power),
        # autarky, ...). A raw sensor without any data returns nil.
        def raw(data, sensor_name, aggregation)
          return unless data.respond_to?(sensor_name)

          data.public_send(sensor_name, aggregation, aggregation)
        end

        # The last bucket of a calendar timeframe, as the timestamp Flux labels
        # it with - or nil where there is nothing to correct.
        #
        # Timeframe#ending is the last nanosecond of the period, and it reaches
        # Flux as the range stop with the fraction cut off (23:59:59).
        # aggregateWindow clips its final bucket at that stop, so a day's last
        # point arrives one second short of the grid every other point sits on:
        # at "1h" a day reads 01:00, 02:00, ..., 23:00, 23:59:59, which a client
        # can only take for a bucket of its own.
        #
        # Left to the serializer rather than fixed in Timeframe: the stop is
        # what every UI chart queries with too, and a global shift would move
        # every one of them for an MCP presentation detail.
        def closing_bucket(timeframe)
          ending = timeframe&.ending
          return unless ending && ending == ending.end_of_day

          Time.zone.parse(ending.iso8601)
        end

        # The bucket's end, on the grid the other points sit on: the closing
        # bucket of a calendar day ends at the next midnight, not one second
        # before it.
        def normalize_time(time, closing)
          (time == closing ? closing + 1.second : time).iso8601
        end

        # Rounded by the unit policy like every other serialized value, then
        # stripped of a signed negative zero: Flux can hand back a -0.0 (e.g. a
        # sensor sitting at 0 around midday), and rounding a small negative
        # value can produce one too. Neither should reach the JSON output.
        def normalize_value(value, unit)
          rounded = McpServer::Precision.round(value, unit)
          return 0.0 if rounded.is_a?(Float) && rounded.zero?

          rounded
        end
      end
    end
  end
end
