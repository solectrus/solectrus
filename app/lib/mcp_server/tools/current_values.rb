module McpServer
  module Tools
    # Returns the latest live reading for each requested sensor (current power
    # flows, battery SOC, temperatures, ...), defaulting to all configured raw
    # sensors. A stale reading (older than a sensor's max_age) or a sensor
    # without data yields a null value, distinct from a measured 0.
    class CurrentValues < Base
      tool_name 'get_current_values'
      title 'Get current sensor values'
      description <<~TEXT.strip
        Get the most recent live reading of each sensor right now: current power
        flows in watts (solar production, grid import/export, house, heatpump,
        wallbox), battery state of charge, temperatures, etc. Optionally restrict
        to specific sensors via the `sensors` parameter (names from
        list_sensors); the response contains exactly those sensors.

        Each sensor carries freshness metadata so a null value is never
        ambiguous:
          - last_seen_at: ISO 8601 timestamp of the latest data point, or null
            if the sensor never reported. With a null value, a present
            last_seen_at means the source was seen before but is now offline;
            a null last_seen_at means it never delivered.
          - age_seconds: how old that reading is (null if never seen).

        A measured 0 is a real value, distinct from null.
      TEXT
      input_schema(
        properties: {
          sensors: {
            type: 'array',
            items: {
              type: 'string',
            },
            description:
              'Optional list of sensor names. Defaults to all configured sensors.',
          },
        },
      )
      read_only idempotent: false

      def self.call(sensors: nil, **)
        definitions = resolve_sensors(sensors, allow_blank: true)
        data = Sensor::Query::Latest.new(definitions.map(&:name)).call
        now = Time.current

        # Return exactly the requested sensors (calculated sensors are derived
        # from their raw dependencies internally, but those dependencies are
        # not leaked into the response). A sensor without a fresh reading
        # yields a null value, distinct from a measured 0.
        values =
          definitions.map do |sensor|
            # The live query defines a (possibly nil-returning) accessor for
            # every requested sensor; guard anyway so a missing accessor reads
            # as "no value" rather than raising.
            value = data.respond_to?(sensor.name) ? data.public_send(sensor.name) : nil
            {
              name: sensor.name,
              display_name: sensor.display_name,
              value:,
              unit: sensor.unit,
              **freshness(sensor, value, data, now),
            }
          end

        json_response(time: data.time&.iso8601, values:)
      rescue ArgumentError => e
        error_response(e.message)
      end

      # Freshness metadata for a single sensor reading. A present value is, by
      # construction, fresh (the live query drops values older than the sensor's
      # max_age); for a null value, last_seen_at distinguishes "seen before but
      # now offline" from "never reported".
      #
      # Raw sensors carry a per-sensor timestamp; calculated sensors don't, so
      # when one produced a value (its dependencies were fresh) we attribute the
      # overall latest reading time to it.
      def self.freshness(sensor, value, data, now)
        last_seen = data.time_for(sensor.name)
        last_seen ||= data.time unless value.nil?

        {
          last_seen_at: last_seen&.iso8601,
          age_seconds: last_seen ? (now - last_seen).round : nil,
        }
      end
      private_class_method :freshness
    end
  end
end
