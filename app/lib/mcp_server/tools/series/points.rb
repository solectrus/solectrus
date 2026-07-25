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
        def build(data, sensor_name, aggregation, include_nulls:)
          buckets = raw(data, sensor_name, aggregation) || {}
          buckets = buckets.compact unless include_nulls

          buckets.sort.map! do |time, value|
            { time: time.iso8601, value: normalize_value(value) }
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

        # Flux can hand back a signed negative zero (e.g. a sensor sitting at 0
        # around midday), which serialises as "-0.0". Collapse it to a plain 0.0
        # so the JSON output never carries a negative zero.
        def normalize_value(value)
          return 0.0 if value.is_a?(Float) && value.zero?

          value
        end
      end
    end
  end
end
