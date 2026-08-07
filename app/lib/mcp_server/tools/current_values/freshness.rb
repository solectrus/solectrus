module McpServer
  module Tools
    class CurrentValues < Base
      # Answers "when did this sensor last deliver anything?" for the reported
      # sensors, so a null value is never ambiguous.
      module Freshness
        module_function

        # { sensor definition => Time or nil }, where nil means the sensor has
        # no data point at all - not merely none in the live window.
        #
        # The live query looks back a day and is the cheap source. A sensor
        # that writes only sporadically (a device reporting on load change) or
        # went offline last week has nothing there, which used to be reported
        # as "never delivered" although get_totals happily returned energy for
        # it. Those sensors - and only those - are resolved over the whole
        # history, in a single additional query.
        def resolve(definitions, data)
          seen = definitions.index_with { |sensor| newest(sensor) { |name| data.time_for(name) } }
          unseen = seen.select { |_sensor, time| time.nil? }.keys
          return seen if unseen.empty?

          history = Sensor::Query::LastSeen.new(unseen.flat_map { sources(it) }.uniq).call
          seen.merge(unseen.index_with { |sensor| newest(sensor) { |name| history[name] } })
        end

        # What a client reads back per sensor: when the sensor last delivered,
        # and how long ago that was.
        #
        # age_seconds accompanies a reported value too. "Fresh by construction"
        # only means "within max_age", which is 15 minutes for most sensors and
        # two hours for the sparse ones - wide enough that two live readings can
        # describe states minutes apart, and a client comparing them has to know
        # by how much. Deriving it from last_seen_at requires the client to know
        # the server's clock, which is exactly what it does not have.
        def metadata(last_seen, now)
          { last_seen_at: last_seen&.iso8601, age_seconds: last_seen ? (now - last_seen).round : nil }
        end

        # Only raw sensors carry a timestamp of their own, so a calculated
        # sensor is as fresh as the newest of the sensors it is derived from.
        def newest(sensor, &)
          sources(sensor).filter_map(&).max
        end

        def sources(sensor)
          return [sensor.name] unless sensor.calculated?

          Sensor::DependencyResolver.new(sensor.name, context: :influx).resolve
        rescue ArgumentError
          # A dependency block needing context kwargs cannot be resolved here;
          # fall back to the sensor itself.
          [sensor.name]
        end
      end
    end
  end
end
