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
        list_sensors); the response contains exactly those sensors. A value of
        null means there is no fresh reading (e.g. the sensor is offline) and is
        distinct from a measured 0.
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

        # Return exactly the requested sensors (calculated sensors are derived
        # from their raw dependencies internally, but those dependencies are
        # not leaked into the response). A sensor without a fresh reading
        # yields a null value, distinct from a measured 0.
        values =
          definitions.map do |sensor|
            {
              name: sensor.name,
              display_name: sensor.display_name,
              value: data.public_send(sensor.name),
              unit: sensor.unit,
            }
          end

        json_response(time: data.time&.iso8601, values:)
      rescue ArgumentError => e
        error_response(e.message)
      end
    end
  end
end
