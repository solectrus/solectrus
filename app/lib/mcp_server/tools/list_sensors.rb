module McpServer
  module Tools
    # Discovery tool: lets the client learn which sensors exist, their units
    # and which aggregations are available. Should be called before
    # get_current_values or get_totals.
    class ListSensors < Base
      tool_name 'list_sensors'
      title 'List available sensors'
      description <<~TEXT.strip
        List the sensors available on this SOLECTRUS instance (solar inverter,
        battery, grid, house, heatpump, finances, ...). Returns each sensor's
        machine name (use these for other tools), human-readable display name,
        unit and the aggregations it supports. Call this first to discover valid
        sensor names.
      TEXT
      input_schema(properties: {})
      read_only idempotent: true

      def self.call(**)
        sensors =
          Sensor::Config.sensors.map do |sensor|
            {
              name: sensor.name,
              display_name: sensor.display_name,
              unit: sensor.unit,
              category: sensor.category,
              calculated: sensor.calculated?,
              aggregations: sensor.allowed_aggregations,
            }
          end

        json_response(sensors:)
      end
    end
  end
end
