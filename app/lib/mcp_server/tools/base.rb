module McpServer
  module Tools
    # Shared base for all SOLECTRUS MCP tools. Subclasses are plain MCP::Tool
    # subclasses, so they keep the gem's `tool_name`/`input_schema` DSL, while
    # this base provides the SOLECTRUS-specific helpers and the one `call`
    # they all share.
    class Base < MCP::Tool
      # Per-request sensor cap, for the tools that run one query per sensor.
      # Stated in the input schema (where a client can act on it before
      # spending a round trip) and enforced by resolve_sensors as the backstop.
      MAX_SENSORS = 20
      public_constant :MAX_SENSORS

      class << self
        # The entry point the MCP gem calls. Subclasses implement `perform` and
        # return the response Hash; serializing it and turning a rejected
        # argument into an error response is identical in all ten tools, so
        # `perform` is left to say only what its tool actually answers.
        def call(**)
          json_response(perform(**))
        rescue ArgumentError => e
          error_response(e.message)
        end

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
                "accepted: #{Facts::TIMEFRAME_FORMS}.",
          }
        end

        # The `sensors` input-schema property. `max` publishes the per-request
        # cap; `required: false` is the one tool that defaults to all sensors.
        def sensors_property(lead, max: nil, required: true)
          {
            type: 'array',
            items: {
              type: 'string',
            },
            **(required ? { minItems: 1 } : {}),
            **(max ? { maxItems: max } : {}),
            description: lead,
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

          raise ArgumentError, "#{e.message}. Accepted: #{Facts::TIMEFRAME_FORMS}."
        end

        # The fields every timeframe-based response opens with. `note:` is false
        # where Facts::TIMEFRAME_NOTE does not apply - a forecast sensor over a
        # future timeframe is the point of the call, not a gap in the data.
        def timeframe_preamble(timeframe, unknown, note: true)
          {
            timeframe: timeframe.to_s,
            **(note ? timeframe_note(timeframe) : {}),
            **unknown_sensors_note(unknown),
          }
        end

        # A `timeframe_note` explaining why a timeframe holds no data, as a hash
        # to splat into the response - empty when it can hold data. Why it has
        # to be said at all: Facts::TIMEFRAME_NOTE.
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
        # rather than raised, for the reason Facts::UNKNOWN_SENSORS gives the
        # client: conventions.suffixes asks it to form _pv/_grid names itself
        # and calls such a name a good guess, so a wrong guess has to cost its
        # own entry instead of the whole call. Only a request with nothing left
        # to answer raises.
        #
        # With `allow_blank`, a blank list defaults to all available sensors;
        # otherwise at least one sensor is required. `max` caps how many
        # resolved sensors a single request may carry.
        def resolve_sensors(names, allow_blank: false, max: nil)
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

          enforce_cap!(definitions, max)

          [definitions, unknown]
        end

        # The runtime half of MAX_SENSORS. The schema states the same number, so
        # a client normally never reaches this - it is the backstop for one that
        # ignores the schema.
        def enforce_cap!(definitions, max)
          return unless max && definitions.size > max

          raise ArgumentError,
                "Too many sensors (max #{max}). list_sensors already carries " \
                  'the name, description and tools of every sensor.'
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
        # coarse `unit` in three MCP-specific ways so a client can trust the
        # unit on its own without re-deriving it from the tool's prose:
        #
        #   - specific_yield is a power normalized by installed capacity
        #     (W/kWp), not a plain power, and summed over time it becomes a
        #     specific energy yield (Wh/kWp). The domain deliberately keeps
        #     :watt there (it drives the aggregation default and the UI's kW
        #     formatting); MCP reports the honest physical unit.
        #   - any other summed :watt sensor becomes watt_hour, per
        #     Facts::WATT_SUM_IS_ENERGY.
        #   - a :gram sensor (co2_reduction) is an AMOUNT only once it has been
        #     aggregated over a period. Unaggregated it is computed from a
        #     power, so it is a rate - the grams avoided per hour at the
        #     current generation - and reporting that as "gram" invited a
        #     client to add live readings up into a daily total. Hence
        #     gram_per_hour live and in a series, gram in get_totals/get_ranking.
        #
        # The money unit is already currency-neutral (:money / :money_per_kwh);
        # the concrete currency is reported once, as an ISO-4217 code, by
        # get_system_info.
        #
        # `aggregation` is nil for live readings and series (no aggregation
        # applied); every non-sum aggregation (avg/min/max) keeps the base unit,
        # because it aggregates values that were already summed per period.
        def mcp_unit(sensor, aggregation = nil)
          case sensor.unit
          when :watt then watt_unit(sensor, aggregation&.to_sym == :sum)
          when :gram then aggregation.nil? ? :gram_per_hour : :gram
          else sensor.unit
          end
        end

        def watt_unit(sensor, summed)
          if sensor.name == :specific_yield
            summed ? :watt_hour_per_kwp : :watt_per_kwp
          else
            summed ? :watt_hour : :watt
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
            "get_current_values has no live reading for these sensors. #{Facts::MONEY_ACCUMULATED} " \
              "#{Facts::SPLIT_CADENCE} #{Facts::SPLIT_INSTEAD} #{Facts::CHART_ONLY}",
          series:
            "get_series has no curve for these sensors. #{Facts::MONEY_ACCUMULATED} " \
              "#{Facts::CHART_ONLY} Use get_totals (Wh/kWh, costs) or get_forecast instead. " \
              "#{Facts::NON_AGGREGATABLE}",
        }.freeze

        # Enforce the supported_tools matrix that list_sensors advertises:
        # raises ArgumentError (which `call` turns into an error response) when
        # any sensor has no meaningful data for `tool`, so a client gets a clear
        # error instead of a silent null series/value.
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
