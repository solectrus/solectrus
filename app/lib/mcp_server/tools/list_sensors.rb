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
        name (use these for other tools), human-readable display name,
        a semantic description, unit and the aggregations it supports. Also
        returns a `conventions` block explaining the naming suffixes and field
        meanings. Call this first to discover valid sensor names.
      TEXT
      input_schema(properties: {})
      read_only idempotent: true

      # Explains the systematic naming/field conventions once, so a client does
      # not have to infer them from ~165 individual sensor names. Unit
      # descriptions are shared (sensor_units), not MCP-specific, and added at
      # call time.
      CONVENTIONS = {
        suffixes: {
          _grid: 'The share of the base sensor supplied from grid import.',
          _pv: 'The share of the base sensor covered by own PV/solar generation.',
          _total: 'Aggregate across all inverters/consumers of the base sensor.',
        },
        calculated:
          'true means the value is derived from other sensors rather than measured directly.',
        forecast:
          'Sensors with category "forecast" hold predicted, not measured, ' \
            'values. get_totals rejects them, so they advertise no ' \
            'aggregations here. Use get_forecast for the expected energy, or ' \
            'get_series ("mean"/"min"/"max") for the predicted curve.',
      }.freeze
      private_constant :CONVENTIONS

      def self.call(**)
        # Force English so the discovery output (display names + descriptions)
        # is deterministic regardless of the instance's locale. User-defined
        # sensor names still take priority, as they are locale-independent.
        I18n.with_locale(:en) do
          sensors =
            Sensor::Config.sensors.map do |sensor|
              {
                name: sensor.name,
                display_name: sensor.display_name,
                description: sensor.description,
                unit: sensor.unit,
                category: sensor.category,
                calculated: sensor.calculated?,
                aggregations: aggregations_for(sensor),
              }
            end

          conventions = CONVENTIONS.merge(units: I18n.t('sensor_units'))
          json_response(sensors:, conventions:)
        end
      end

      # The aggregations a client can actually use across the MCP tools.
      # Forecast sensors are rejected by get_totals (and "sum" is rejected for
      # power sensors in get_series), so a forecast sensor's stored aggregation
      # (e.g. [:sum] on inverter_power_forecast) is usable nowhere - advertising
      # it would promise an aggregation the tools later reject. Report none; the
      # `forecast` convention explains how to access these sensors instead.
      def self.aggregations_for(sensor)
        return [] if sensor.forecast?

        sensor.allowed_aggregations
      end
      private_class_method :aggregations_for
    end
  end
end
