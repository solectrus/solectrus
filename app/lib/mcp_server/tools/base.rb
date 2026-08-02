module McpServer
  module Tools
    # Shared base for all SOLECTRUS MCP tools. Subclasses are plain MCP::Tool
    # subclasses, so they keep the gem's `tool_name`/`input_schema`/`call` DSL,
    # while this base provides a few SOLECTRUS-specific helpers.
    class Base < MCP::Tool
      class << self
        # Declare the annotations shared by every (read-only) SOLECTRUS tool.
        # `idempotent:` says whether repeating an identical call yields the same
        # result - false for live readings, true for historical aggregates.
        def read_only(idempotent:)
          annotations(
            read_only_hint: true,
            destructive_hint: false,
            idempotent_hint: idempotent,
            open_world_hint: false,
          )
        end

        protected

        # The forms a `timeframe` parameter accepts, named once so an error can
        # state them instead of leaving a client to guess from the tool
        # description it evidently misread.
        TIMEFRAME_FORMS =
          '"2026-06-21" (a day), "2026-W25" (a week), "2026-06" (a month), ' \
            '"2026" (a year), "2026-01-01..2026-03-31" (a date range), "P24H"/' \
            '"P30D"/"P12M" (rolling), "day"/"week"/"month"/"year" (the current ' \
            'period), "all" (since installation)'.freeze
        private_constant :TIMEFRAME_FORMS

        # Timeframe.new, with the accepted forms appended to the error. The
        # domain class stays free of that prose: which forms exist is its
        # business, but spelling them out for a language model is this layer's.
        def parse_timeframe(string)
          Timeframe.new(string)
        rescue ArgumentError => e
          raise e unless e.message.end_with?('is not a valid timeframe')

          raise ArgumentError, "#{e.message}. Accepted: #{TIMEFRAME_FORMS}."
        end

        # A `timeframe_note` explaining why a timeframe holds no data, as a hash
        # to splat into the response - empty when it can hold data.
        #
        # Without it, a timeframe in the future and one before the system
        # existed both come back as a null value, indistinguishable from a
        # sensor outage - and a model reports "no data" where it should report
        # "not yet" or "not back then".
        def timeframe_note(timeframe)
          installation = Rails.configuration.x.installation_date

          if timeframe.beginning.to_date > Date.current
            {
              timeframe_note:
                'This timeframe lies entirely in the future, so nothing has ' \
                  'been measured for it yet. Use get_forecast for what is expected.',
            }
          elsif installation && timeframe.ending.to_date < installation
            {
              timeframe_note:
                'This timeframe ends before the installation date ' \
                  "(#{installation.iso8601}), so no data was ever recorded for it.",
            }
          else
            {}
          end
        end

        # Resolve client-supplied sensor names to the corresponding Sensor
        # definitions, validated against the sensors actually configured and
        # permitted on this instance (Sensor::Config.sensors). Names outside
        # that set - unknown, unconfigured, or not permitted by policy - raise
        # ArgumentError, so a tool surfaces a clean error instead of leaking
        # data for sensors that list_sensors never advertised.
        #
        # With `allow_blank`, a blank list defaults to all available sensors;
        # otherwise at least one sensor is required.
        def resolve_sensors(names, allow_blank: false)
          available = Sensor::Config.sensors

          if names.blank?
            return available if allow_blank

            raise ArgumentError, 'Provide at least one sensor'
          end

          by_name = available.index_by(&:name)
          requested = Array(names).map { |name| name.to_s.to_sym }

          unknown = requested - by_name.keys
          if unknown.any?
            raise ArgumentError,
                  "Unknown or unconfigured sensors: #{unknown.join(', ')}. " \
                    'Call list_sensors for the names this instance actually has.'
          end

          requested.map { |name| by_name[name] }
        end

        # The unit a sensor's value carries in MCP output, refining the domain's
        # coarse `unit` in two MCP-specific ways so a client can trust the unit
        # on its own without re-deriving it from the tool's prose:
        #
        #   - specific_yield is a power normalized by installed capacity
        #     (W/kWp), not a plain power, and summed over time it becomes a
        #     specific energy yield (Wh/kWp). The domain deliberately keeps
        #     :watt there (it drives the aggregation default and the UI's kW
        #     formatting); MCP reports the honest physical unit.
        #   - summing any other :watt sensor integrates power over time and
        #     yields an ENERGY, so its aggregated unit is watt_hour, not watt.
        #
        # The money unit is already currency-neutral (:money / :money_per_kwh);
        # the concrete currency is reported once, as an ISO-4217 code, by
        # get_system_info.
        #
        # `aggregation` is nil for live readings and series (no aggregation
        # applied); every non-sum aggregation (avg/min/max) keeps the base unit.
        def mcp_unit(sensor, aggregation = nil)
          summed = aggregation&.to_sym == :sum

          if sensor.name == :specific_yield
            summed ? :watt_hour_per_kwp : :watt_per_kwp
          elsif summed && sensor.unit == :watt
            :watt_hour
          else
            sensor.unit
          end
        end

        # Wrap a Ruby Hash/Array as a JSON text response.
        def json_response(data)
          MCP::Tool::Response.new([{ type: 'text', text: data.to_json }])
        end

        def error_response(message)
          MCP::Tool::Response.new([{ type: 'text', text: message }], error: true)
        end

        # Hint explaining why a tool has no data for the rejected sensors,
        # pointing at the right tool instead.
        UNSUPPORTED_HINT = {
          current:
            'get_current_values has no live reading for these sensors. Money ' \
              'sensors (costs, revenue) are accumulated amounts - use get_totals ' \
              'over a timeframe; chart-only composites (e.g. power_balance) have ' \
              'no live scalar.',
          series:
            'get_series has no curve for these sensors. Money sensors (costs, ' \
              'revenue) are accumulated amounts and chart-only composites (e.g. ' \
              'power_balance) have no live curve - use get_totals (Wh/kWh, costs) ' \
              'or get_forecast.',
        }.freeze

        # Enforce the supported_tools matrix that list_sensors advertises:
        # raises ArgumentError (which each tool's `call` rescues into an error
        # response) when any sensor has no meaningful data for `tool`, so a
        # client gets a clear error instead of a silent null series/value.
        def enforce_supported!(definitions, tool)
          unsupported =
            definitions.reject { McpServer::SupportedTools.supports?(it, tool) }
          return if unsupported.none?

          raise ArgumentError,
                "#{UNSUPPORTED_HINT[tool]} Affected: #{unsupported.map(&:name).join(', ')}."
        end
      end
    end
  end
end
