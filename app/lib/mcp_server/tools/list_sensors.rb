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
        returns a `conventions` block explaining the naming suffixes, the field
        meanings and — under `precision` — how many decimals each unit is
        rounded to, so you never have to guess whether a value was rounded.
        Call this first to discover valid sensor names.
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
        supported_tools:
          'Per sensor, which tools return meaningful data for it, so a client ' \
            'need not learn each tool\'s rules by trial: current ' \
            '(get_current_values), totals (get_totals), series (get_series), ' \
            'ranking (get_ranking), forecast (get_forecast). current and ' \
            'series are strict: a false flag means the tool rejects the sensor ' \
            '(a chart-only composite like power_balance, or a money sensor, ' \
            'has no live scalar). totals and ranking are advisory: false marks ' \
            'sensors outside the primary/curated set - get_totals may still ' \
            'return a null or sibling-derived value, and get_ranking can still ' \
            'rank any summary-backed sensor (e.g. battery_soc). Prefer ' \
            'true-flagged sensors, but do not treat false as a hard block for ' \
            'totals/ranking.',
      }.freeze
      private_constant :CONVENTIONS

      # Publishes the rounding policy so a client knows the precision it is
      # getting instead of having to guess whether a value was rounded - which
      # is what decides whether further arithmetic on it is valid.
      PRECISION = {
        note:
          'Decimals every tool rounds a value to, keyed by the sensor\'s unit ' \
            'and by nothing else - so the same sensor reads identically in ' \
            'get_current_values, get_totals, get_series and get_ranking. A ' \
            'unit with 0 decimals is serialized as an integer, any other as a ' \
            'float. Units not listed here (boolean, string) pass through ' \
            'unchanged. Note that a summed watt sensor is rounded as the ' \
            'watt_hour it has become, not as a watt.',
        decimals: McpServer::Precision::DECIMALS,
      }.freeze
      private_constant :PRECISION

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
                unit: mcp_unit(sensor),
                category: sensor.category,
                calculated: sensor.calculated?,
                aggregations: McpServer::SupportedTools.aggregations(sensor),
                supported_tools: McpServer::SupportedTools.for(sensor),
              }
            end

          conventions =
            CONVENTIONS.merge(units: I18n.t('sensor_units'), precision: PRECISION)
          json_response(sensors:, conventions:)
        end
      end
    end
  end
end
