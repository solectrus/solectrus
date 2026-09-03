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

          - unit: the UNAGGREGATED unit — get_totals and get_ranking report the
            unit after aggregation instead, which for a summed watt sensor is
            watt_hour. Units are explained in list_sensors' conventions.
          - category: inverter, battery, grid, consumer, economic, forecast, ...
          - calculated: derived rather than measured, in Ruby or in SQL. True
            for every economic sensor (nothing meters a cost) and for both
            halves of a power split. False means a device wrote the number.
          - aggregations: exactly what get_ranking accepts for its
            `aggregation`, with default_aggregation the one get_totals applies.
            An empty list (and a null default) means both tools reject the
            sensor — there is no per-period value to give.
          - display_name, description and tools: as in list_sensors, but for a
            _grid/_pv split too, which that index leaves out.

        You will rarely need this: the data tools report unit and display name
        for what they return, and `tools` from list_sensors decides which tool
        to call. Reach for it to commit to a unit or an aggregation BEFORE a
        call, or to explain a sensor to a user. Asking for everything rebuilds
        the payload list_sensors exists to avoid.
      TEXT
      input_schema(
        properties: {
          sensors:
            sensors_property(
              "Sensor names, at most #{MAX_SENSORS}. list_sensors resolves a name you do not know.",
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
          display_name: mcp_display_name(sensor),
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
