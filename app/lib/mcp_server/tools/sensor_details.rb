module McpServer
  module Tools
    # The per-sensor metadata that list_sensors deliberately leaves out: unit,
    # display name, category, whether the value is calculated, and which
    # aggregations it supports. Requested for a handful of sensors at a time,
    # which is what keeps the discovery index affordable.
    class SensorDetails < Base
      # A details request for dozens of sensors is the payload list_sensors was
      # just slimmed down to avoid, so bound it.
      MAX_SENSORS = 20
      private_constant :MAX_SENSORS

      tool_name 'get_sensor_details'
      title 'Get full metadata for specific sensors'
      description <<~TEXT.strip
        Full metadata of specific sensors, beyond the name, description and
        `tools` that list_sensors returns for all of them:

          - display_name: the human-readable label.
          - unit: the UNAGGREGATED unit — note that get_totals/get_ranking
            report the unit after aggregation, where a summed "watt" becomes
            "watt_hour". Units are explained in list_sensors' conventions.
          - category: inverter, battery, grid, consumer, economic, forecast, ...
          - calculated: the value is derived from other sensors, not measured.
          - aggregations: what is usable across the tools; empty for forecast
            sensors, which get_totals rejects.
          - tools: the same code list_sensors returns — c = get_current_values,
            t = get_totals, s = get_series, r = get_ranking, f = get_forecast.
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
          sensors: {
            type: 'array',
            items: {
              type: 'string',
            },
            description: "Sensor names (from list_sensors), at most #{MAX_SENSORS}.",
          },
        },
        required: %w[sensors],
      )
      read_only idempotent: true

      def self.call(sensors:, **)
        definitions, unknown = resolve_sensors(sensors)
        if definitions.size > MAX_SENSORS
          raise ArgumentError,
                "Too many sensors (max #{MAX_SENSORS}). list_sensors already " \
                  'carries the name, description and tools of every sensor.'
        end

        # English for the same reason as list_sensors: discovery output must not
        # depend on the instance's locale. User-defined sensor names still take
        # priority, as they are locale-independent.
        I18n.with_locale(:en) do
          json_response(
            **unknown_sensors_note(unknown),
            sensors: definitions.map { details_for(it) },
          )
        end
      rescue ArgumentError => e
        error_response(e.message)
      end

      def self.details_for(sensor)
        {
          name: sensor.name,
          display_name: sensor.display_name,
          description: sensor.description,
          unit: mcp_unit(sensor),
          category: sensor.category,
          calculated: sensor.calculated?,
          aggregations: McpServer::SupportedTools.aggregations(sensor),
          tools: McpServer::SupportedTools.code(sensor),
        }
      end
      private_class_method :details_for
    end
  end
end
