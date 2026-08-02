module McpServer
  module Tools
    # Shared base for all SOLECTRUS MCP tools. Subclasses are plain MCP::Tool
    # subclasses, so they keep the gem's `tool_name`/`input_schema`/`call` DSL,
    # while this base provides a few SOLECTRUS-specific helpers.
    class Base < MCP::Tool
      # Every `timeframe` spelling there is, in one place: the input schemas
      # publish it up front and parse_timeframe repeats it when a client got it
      # wrong anyway. There are few enough forms to list them all, and listing
      # them all is the point - an "e.g." invites a model to extrapolate, and
      # what it extrapolates ("last-week", "yesterday", "2026-06-21..now") is
      # never accepted. A closed set leaves nothing to invent.
      TIMEFRAME_FORMS =
        '"2026-06-21" (a day), "2026-W25" (a week), "2026-06" (a month), ' \
          '"2026" (a year), "2026-01-01..2026-03-31" (a date range), ' \
          '"P24H"/"P30D"/"P12M" (a rolling window ending now), ' \
          '"day"/"week"/"month"/"year" (the current period), ' \
          '"all" (since installation)'.freeze
      public_constant :TIMEFRAME_FORMS

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

        # The `timeframe` input-schema property. `lead` carries what the
        # individual tool needs on top (get_series rejects the instant "now",
        # get_ranking ranks periods within the range); the accepted forms
        # themselves are the same everywhere and stated as a closed set.
        def timeframe_property(lead)
          {
            type: 'string',
            description:
              "#{lead} Use exactly one of these forms, nothing else is " \
                "accepted: #{TIMEFRAME_FORMS}.",
          }
        end

        protected

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
        # that set - unknown, unconfigured, or not permitted by policy - never
        # yield data, so a tool cannot leak sensors that list_sensors never
        # advertised.
        #
        # Returns [definitions, unknown_names]. A bad name is reported back
        # rather than raised: conventions.suffixes asks clients to form
        # _pv/_grid names themselves and calls such a name "a good guess, not a
        # guarantee", so a wrong guess has to cost its own entry instead of the
        # whole call - two valid sensors alongside it are still two answers.
        # Only a request with nothing left to answer raises.
        #
        # With `allow_blank`, a blank list defaults to all available sensors;
        # otherwise at least one sensor is required.
        def resolve_sensors(names, allow_blank: false)
          available = Sensor::Config.sensors

          if names.blank?
            return [available, []] if allow_blank

            raise ArgumentError, 'Provide at least one sensor'
          end

          by_name = available.index_by(&:name)
          requested = Array(names).map { |name| name.to_s.to_sym }

          definitions = requested.filter_map { |name| by_name[name] }
          unknown = requested - by_name.keys

          if definitions.empty?
            raise ArgumentError,
                  "Unknown or unconfigured sensors: #{unknown.join(', ')}. " \
                    'Call list_sensors for the names this instance actually has.'
          end

          [definitions, unknown]
        end

        # The `unknown_sensors` report, as a hash to splat into the response -
        # empty when every name resolved, so the common case pays nothing.
        # Without it a skipped name would be silent, and a client comparing
        # three requested sensors against two returned ones could only guess
        # which of its guesses missed.
        def unknown_sensors_note(unknown)
          return {} if unknown.empty?

          {
            unknown_sensors: unknown,
            unknown_sensors_note:
              'Not configured on this instance and skipped; the other sensors ' \
                'were answered normally. Call list_sensors for the names this ' \
                'instance actually has.',
          }
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
              'or get_forecast. Boolean and string sensors (e.g. a car-connected ' \
              'flag, a status text) cannot be averaged into a bucket at all - ' \
              'get_current_values reports their present state.',
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

        # The same shape of gate for get_ranking, which cannot go through the
        # matrix above: "r" marks the curated Top10 set, while a ranking is
        # possible for every sensor the summaries store. Why a derived one has
        # none at all, and what the query would otherwise guess:
        # Sensor::Definitions::Base#rankable?.
        #
        # A sensor with no aggregation at all (a status string) is left to the
        # more specific complaint about that, raised per sensor further down.
        def enforce_rankable!(definitions)
          unrankable =
            definitions.reject { it.rankable? || it.default_aggregation.nil? }
          return if unrankable.none?

          raise ArgumentError,
                'get_ranking has no ranking for these sensors: they are ' \
                  'derived from other sensors rather than stored in the ' \
                  'summaries, so there is no per-period value to order by. Use ' \
                  'get_totals for their value over a timeframe, or get_series ' \
                  "for their curve. Affected: #{unrankable.map(&:name).join(', ')}."
        end
      end
    end
  end
end
