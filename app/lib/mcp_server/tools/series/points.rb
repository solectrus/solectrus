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
        def build(data, sensor_name, aggregation, unit:, include_nulls:)
          buckets = raw(data, sensor_name, aggregation) || {}
          buckets = buckets.compact unless include_nulls

          buckets.sort.map! do |time, value|
            { time: time.iso8601, value: normalize_value(value, unit) }
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
