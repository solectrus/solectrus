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
                  "Unknown or unconfigured sensors: #{unknown.join(', ')}"
          end

          requested.map { |name| by_name[name] }
        end

        # Wrap a Ruby Hash/Array as a JSON text response.
        def json_response(data)
          MCP::Tool::Response.new([{ type: 'text', text: data.to_json }])
        end

        def error_response(message)
          MCP::Tool::Response.new([{ type: 'text', text: message }], error: true)
        end
      end
    end
  end
end
