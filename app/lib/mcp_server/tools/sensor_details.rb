module McpServer
  module Tools
    # The per-sensor metadata that list_sensors deliberately leaves out: unit,
    # display name, category, whether the value is calculated, and which
    # aggregations it supports. Requested for a handful of sensors at a time,
    # which is what keeps the discovery index affordable.
    class SensorDetails < Base
      tool_name 'get_sensor_details'
      title 'Get full metadata for specific sensors'
      description <<~TEXT.strip
        Full metadata of specific sensors, beyond the name, description and
        `tools` that list_sensors returns for all of them:

          - display_name: the human-readable label.
          - unit: the UNAGGREGATED unit — note that get_totals/get_ranking
            report the unit after aggregation. #{Facts::WATT_SUM_IS_ENERGY}
            Units are explained in list_sensors' conventions.
          - category: inverter, battery, grid, consumer, economic, forecast, ...
          - calculated: derived rather than measured, in Ruby or in SQL. True
            for every economic sensor (nothing meters a cost) and for both
            halves of a power split. False means a device wrote the number.
          - aggregations: exactly what get_ranking accepts for its
            `aggregation`. Empty where the sensor has none.
          - default_aggregation: the one get_totals applies and get_ranking
            defaults to. null where there is none.
          - tools: the same code list_sensors returns, whose `conventions` block
            explains the letters.
          - description: also for the _grid/_pv split sensors, where
            list_sensors omits it.

        You will rarely need this: every data tool already reports unit and
        display name for what it returns, and `tools` from list_sensors decides
        which tool to call. Reach for it to commit to a unit or an aggregation
        BEFORE a call, or to explain a sensor to a user.

        At most #{MAX_SENSORS} names — asking for everything rebuilds the
        payload list_sensors exists to avoid.
      TEXT
      input_schema(
        properties: {
          sensors:
            sensors_property(
              "Sensor names (from list_sensors), at most #{MAX_SENSORS}.",
              max: MAX_SENSORS,
            ),
        },
        required: %w[sensors],
      )
      read_only idempotent: true

      def self.perform(sensors:, **)
        definitions, unknown = resolve_sensors(sensors, max: MAX_SENSORS)

        # English for the same reason as list_sensors: discovery output must not
        # depend on the instance's locale. User-defined sensor names still take
        # priority, as they are locale-independent.
        I18n.with_locale(:en) do
          {
            **unknown_sensors_note(unknown),
            sensors: definitions.map { details_for(it) },
          }
        end
      end

      def self.details_for(sensor)
        {
          name: sensor.name,
          display_name: sensor.display_name,
          description: sensor.description,
          unit: mcp_unit(sensor),
          category: sensor.category,
          calculated: McpServer::SupportedTools.calculated?(sensor),
          aggregations: McpServer::SupportedTools.aggregations(sensor),
          default_aggregation: McpServer::SupportedTools.default_aggregation(sensor),
          tools: McpServer::SupportedTools.code(sensor),
        }
      end
      private_class_method :details_for
    end
  end
end
