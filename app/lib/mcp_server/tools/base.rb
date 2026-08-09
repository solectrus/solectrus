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

        # Timeframe.new, with an error a model can act on. The domain class
        # stays free of that prose: which forms exist is its business, but
        # spelling them out for a language model is this layer's.
        #
        # `beginning` is touched on purpose. Timeframe validates by regex
        # alone, so a well-shaped but impossible date ("2026-02-30",
        # "2026-W99") passes the constructor and only fails later, deep inside
        # a query, as a bare "invalid date" naming neither the argument that
        # was wrong nor what a right one looks like.
        def parse_timeframe(string)
          Timeframe.new(string).tap(&:beginning)
        rescue ArgumentError
          raise ArgumentError, invalid_timeframe(string)
        end

        # An hour window past the bound, e.g. "P120H". It is a valid FORM with
        # a number the grammar does not carry, so it is not a typo - and the
        # generic message reads the whole grammar back at a client that
        # already wrote a correct form, without ever naming the one number it
        # got wrong.
        OVERLONG_HOURS = /\AP\d+H\z/
        private_constant :OVERLONG_HOURS

        # One message per way a timeframe can be wrong, each ending in the fix.
        # The specific ones come first: where a single concrete string is the
        # fix, listing the whole grammar would bury it.
        def invalid_timeframe(string)
          overlong_hours(string) || invalid_range(string) ||
            "'#{string}' is not a valid timeframe. Accepted: #{Facts::TIMEFRAME_FORMS}."
        end

        def overlong_hours(string)
          return unless string.to_s.match?(OVERLONG_HOURS)

          "Invalid timeframe \"#{string}\": an hour window ends at " \
            "#{Timeframe::MAX_HOURS} hours (\"P#{Timeframe::MAX_HOURS}H\"). " \
            'It is read from raw samples, which a wider window makes ' \
            'expensive. Ask in whole days instead ("P5D", ending yesterday) ' \
            'or name a date range.'
        end

        def invalid_range(string)
          from, to = range_dates(string)
          return unless from && to

          if from > to
            "Invalid timeframe \"#{string}\": the end date must be AFTER the " \
              "start date. Use \"#{to}..#{from}\"."
          elsif from == to
            "Invalid timeframe \"#{string}\": a range spans at least two days. " \
              "For a single day use \"#{from}\"."
          end
        end

        # The two dates of a "from..to" string, or nothing where the string is
        # not that shape or either half is not a date.
        def range_dates(string)
          from, to, extra = string.to_s.split('..')
          return if to.blank? || extra

          [Date.parse(from), Date.parse(to)]
        rescue Date::Error
          nil
        end

        # The fields every timeframe-based response opens with. `note:` is false
        # where Facts::TIMEFRAME_NOTE does not apply - a forecast sensor over a
        # future timeframe is the point of the call, not a gap in the data.
        #
        # `running:` adds the third case to that note, and only get_totals asks
        # for it: a curve and a ranking mark the same fact on the entry it
        # applies to (`partial_at`), so for them the note would repeat per call
        # what the payload already says per value. A total has no entry to
        # carry it - one number for the whole period, and nothing in it says
        # the period is half over.
        def timeframe_preamble(timeframe, unknown, note: true, running: false)
          {
            timeframe: timeframe.to_s,
            **(note ? timeframe_note(timeframe, running:) : {}),
            **unknown_sensors_note(unknown),
          }
        end

        # A `timeframe_note` explaining why a timeframe holds no data - or less
        # of it than its name suggests - as a hash to splat into the response,
        # empty when there is nothing to say. Why the first two have to be said
        # at all: Facts::TIMEFRAME_NOTE.
        def timeframe_note(timeframe, running: false)
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
          elsif running && timeframe.ending > Time.current
            {
              timeframe_note:
                'This period has not ended yet, so every value covers it only ' \
                  'up to now. A SUMMED value is therefore smaller for being ' \
                  'cut short, not for measuring less. An AVERAGED one (see ' \
                  "each entry's `aggregation`) is not smaller at all - it is " \
                  'the mean of a shorter stretch. Never compare either with a ' \
                  'completed period.',
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
        # `blank_message` is what a tool with more than one way to name a sensor
        # has to say instead of the default: get_ranking takes either `sensors`
        # or `sensor`, and its schema can only mark both optional, so the error
        # is the one place a client learns that one of them is required.
        def resolve_sensors(names, allow_blank: false, max: nil, blank_message: nil)
          available = Sensor::Config.sensors

          if names.blank?
            return [available, []] if allow_blank

            raise ArgumentError,
                  blank_message ||
                    'Provide at least one sensor name in `sensors`. Call ' \
                      'list_sensors for the names this instance has.'
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

        # A soft hyphen marks where a browser MAY break a word. It is invisible,
        # it is not part of the name, and it has no meaning outside a rendered
        # page - but it survives JSON, so a client echoes it back at the user
        # and a comparison against "Hausverbrauch" fails for a reason nobody can
        # see.
        SOFT_HYPHEN = "\u00AD".freeze
        private_constant :SOFT_HYPHEN

        # The sensor's name as DATA rather than as layout.
        #
        # Stripped here rather than at the source because the source is
        # Setting.sensor_names, which holds whatever an admin saved in the
        # settings form - and a break in "Haus-verbrauch" is right on a
        # rendered page. Removing it there would take it away from the page
        # that wants it.
        def mcp_display_name(sensor)
          sensor.display_name.delete(SOFT_HYPHEN)
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

        # The sentence a rejection opens with, per tool. What follows is the
        # reason, per sensor.
        UNSUPPORTED_LEAD = {
          current: 'get_current_values has no live reading for these sensors.',
          series: 'get_series has no curve for these sensors.',
          totals: 'get_totals has no total for these sensors.',
          ranking: 'get_ranking has no ranking for these sensors.',
        }.freeze

        # One fact per reason McpServer::SupportedTools can report. Only the
        # reasons a request actually hit are sent: a client asking for one
        # sensor should not have to work out which of four paragraphs describes
        # it.
        #
        # None of them names a tool to ask instead - that half is composed from
        # the matrix, per sensor, by #instead_clause.
        UNSUPPORTED_REASON = {
          money: Facts::MONEY_ACCUMULATED,
          split: "#{Facts::SPLIT_CADENCE} #{Facts::SPLIT_INSTEAD}",
          chart_only: Facts::CHART_ONLY,
          non_aggregatable: Facts::NON_AGGREGATABLE,
          no_aggregation: Facts::NO_AGGREGATION,
          forecast: Facts::FORECAST_NOT_MEASURED,
          not_summarized: Facts::NOT_SUMMARIZED,
        }.freeze

        # Reasons whose fact already says what to ask instead, and says it more
        # specifically than the matrix can: a live power split sends the client
        # to the BASE sensor, which is a different sensor rather than a
        # different tool, so no matrix could have named it.
        SELF_EXPLAINING = %i[split].freeze
        private_constant :SELF_EXPLAINING

        # Enforce the supported_tools matrix that list_sensors advertises:
        # raises ArgumentError (which `call` turns into an error response) when
        # any sensor has no meaningful data for `tool`, so a client gets a clear
        # error instead of a silent null series/value.
        #
        # `unknown` travels along because a rejection ends the whole call, and
        # the names resolve_sensors skipped would be lost with it.
        def enforce_supported!(definitions, tool, unknown = [])
          unsupported =
            definitions.reject { McpServer::SupportedTools.supports?(it, tool) }
          return if unsupported.none?

          raise ArgumentError,
                [
                  UNSUPPORTED_LEAD[tool],
                  *unsupported_reasons(unsupported, tool),
                  *skipped_note(unknown),
                ].join(' ')
        end

        # The rejected sensors grouped by reason AND by what is left to ask, so
        # each combination is stated once and carries the names it applies to.
        # Grouping by the reason alone would have been shorter and wrong: two
        # sensors can be rejected for the same reason and still have different
        # tools left over.
        def unsupported_reasons(unsupported, tool)
          unsupported
            .group_by { [McpServer::SupportedTools.rejection(it, tool), instead_clause(it, tool)] }
            .map do |(reason, instead), sensors|
              "#{sensors.map(&:name).join(', ')}: #{UNSUPPORTED_REASON[reason]}#{instead}"
            end
        end

        # What to ask instead, read off the matrix rather than remembered - so
        # a rejection can never name a tool that rejects the sensor too. "No
        # tool answers for it" is an answer as well, and the one a chart-only
        # composite needs: without it a client keeps trying.
        def instead_clause(sensor, tool)
          reason = McpServer::SupportedTools.rejection(sensor, tool)
          return '' if SELF_EXPLAINING.include?(reason)

          others = McpServer::SupportedTools.alternatives(sensor, except: tool)
          return ' No other tool answers for it.' if others.empty?

          " Use #{tool_list(others)} instead."
        end

        def tool_list(flags)
          flags
            .map { Facts.tool_name(it) }
            .to_sentence(two_words_connector: ' or ', last_word_connector: ' or ')
        end

        # An unknown name is normally reported in `unknown_sensors` and the call
        # answered anyway. Where something else fails the call outright, that
        # report never gets built, so the name is carried into the error
        # instead: a client sending one good name, one rejected and one typo
        # otherwise learns about the typo only on a second round trip.
        def skipped_note(unknown)
          return [] if unknown.empty?

          ["Also not configured on this instance and skipped: #{unknown.join(', ')}."]
        end
      end
    end
  end
end
