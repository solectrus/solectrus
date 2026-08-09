module McpServer
  module Tools
    # Discovery tool: lets the client learn which sensors exist and what each
    # one means. Deliberately an index, not a datasheet - the per-sensor
    # datasheet is get_sensor_details.
    class ListSensors < Base
      tool_name 'list_sensors'
      title 'List available sensors'
      description <<~TEXT.strip
        The sensors this SOLECTRUS instance has (solar inverter, battery, grid,
        house, heatpump, finances, ...). Call this first: every other tool takes
        these names.

        Per sensor: `name`, a semantic description, and `tools` — which tools
        return meaningful data for it. Plus `display_name` wherever the operator
        named the sensor themselves, which is the word the user will say, so
        match their wording against it: "Waschmaschine" is custom_power_01,
        whose name and description only ever say "custom consumer 1". Its
        absence means the sensor carries no name of its own, not that it has
        none to show.

        An index, not a datasheet: unit, category and aggregations for several
        hundred sensors would cost far more up front than they are worth, and
        every data tool reports unit and display name for what it returns
        anyway. get_sensor_details fills them in for a few named sensors.

        The `conventions` block in the response explains the rest: the `tools`
        letters, the _grid/_pv sensors this index leaves out, the units, and the
        decimals each unit is rounded to.
      TEXT
      input_schema(properties: {})
      read_only idempotent: true

      # Explains the systematic naming/field conventions once, so a client does
      # not have to infer them from a few hundred individual sensor names. Unit
      # descriptions are shared (sensor_units), not MCP-specific, and added at
      # call time.
      CONVENTIONS = {
        suffixes: {
          note:
            'The _grid and _pv variants are NOT listed under `sensors`: they ' \
              'split a base sensor by energy source, and on an instance with ' \
              'many consumers they are 40 % of this response without carrying ' \
              'anything their name does not. Only the bases in `split_bases` ' \
              'have them, most in both directions but not all, so a name formed ' \
              'off that list is a good guess rather than a guarantee - a miss ' \
              'comes back in `unknown_sensors`, it does not fail the call. ' \
              "#{McpServer::Facts::SPLIT_CADENCE} So a split carries no c (ask " \
              'the base sensor for live power), and get_series answers for it ' \
              'only over a timeframe that has ENDED and never finer than the ' \
              'splitter cycle. get_totals and get_ranking have no such ' \
              'condition. get_sensor_details gives a split its description and ' \
              'its own `tools`.',
          _grid: 'The share of the base sensor supplied from grid import.',
          _pv: 'The share of the base sensor covered by own PV/solar generation.',
          _total: 'Aggregate across all inverters/consumers of the base sensor.',
        },
        forecast:
          'A sensor whose description says "forecasted" holds predicted, not ' \
            'measured, values: it carries "f" and never "t". Use get_forecast ' \
            'for the expected energy, get_series for the predicted curve. ' \
            'get_ranking answers for one the summaries store ("r"), but it ' \
            'ranks what was PREDICTED for a past period, not what arrived.',
        tools:
          'Which tools return meaningful data for this sensor, one letter ' \
            "each: #{McpServer::Facts.tool_letters}. " \
            "#{McpServer::Facts::TOOL_STRICTNESS} Why a letter is missing: a " \
            'money sensor has no live scalar (neither c nor s); a boolean or ' \
            'string sensor has a state but no curve (c without s); a sensor ' \
            'with no aggregation at all has nothing to total or rank (neither ' \
            't nor r); and a sensor derived from others rather than stored in ' \
            'the summaries has no r (the _pv power splits, ' \
            'house_power_without_custom, grid_balance). A sensor NO tool ' \
            'answers for is not listed here at all - a chart-only composite ' \
            'such as power_balance, which exists to feed a chart and carries ' \
            'no value of its own. get_sensor_details describes it by name.',
      }.freeze
      private_constant :CONVENTIONS

      # Publishes the rounding policy so a client knows the precision it is
      # getting instead of having to guess whether a value was rounded - which
      # is what decides whether further arithmetic on it is valid.
      PRECISION = {
        note:
          'Decimals a value is rounded to, keyed by its unit and by nothing ' \
            'else - so a sensor reads identically in every tool. 0 decimals ' \
            'serializes as an integer, anything else as a float; units not ' \
            'listed (boolean, string) pass through unchanged. A summed watt ' \
            'sensor is rounded as the watt_hour it has become. Every value is ' \
            'rounded on its own, so an identity between sensors can be off by ' \
            'the last digit - self_consumption 1 Wh away from inverter_power ' \
            'minus grid_export_power. That is the rounding, not an ' \
            'inconsistency in the data; do not report it as one.',
        decimals: McpServer::Precision::DECIMALS,
      }.freeze
      private_constant :PRECISION

      def self.perform(**)
        # Force English so the discovery output (descriptions) is deterministic
        # regardless of the instance's locale.
        I18n.with_locale(:en) do
          splits, listed = McpServer::SplitSensors.partition(Sensor::Config.sensors)

          { sensors: answerable(listed).map { entry_for(it) }, conventions: conventions_for(splits) }
        end
      end

      # An index exists so a client can PICK a sensor to call something with.
      # A sensor with an empty `tools` is the one entry that can never be
      # picked: every tool rejects it, and the letters say so. Listing it costs
      # a description and a name to advertise a dead end - and invites the call
      # the letters were meant to prevent. get_sensor_details still answers for
      # it by name, as it does for the splits this index leaves out.
      def self.answerable(sensors)
        sensors.reject { McpServer::SupportedTools.code(it).empty? }
      end
      private_class_method :answerable

      # `display_name` only where the operator set one. Those names are the
      # words the user actually says ("Wie viel zieht die Waschmaschine?"), and
      # no client could map them onto custom_power_01 from its name or its
      # description, both of which only ever say "custom consumer 1". Where no
      # name was set, the label is the sensor's name in prose and would cost
      # bytes to say twice.
      def self.entry_for(sensor)
        {
          name: sensor.name,
          **(sensor.user_defined_name? ? { display_name: mcp_display_name(sensor) } : {}),
          description: sensor.description,
          tools: McpServer::SupportedTools.code(sensor),
        }
      end
      private_class_method :entry_for

      # The bases are read back off the splits that actually exist rather than
      # assumed symmetric, so a family carrying only one of the two suffixes
      # still lists its base, and exactly once.
      def self.conventions_for(splits)
        bases = splits.to_set { McpServer::SplitSensors.base_name(it.name) }.sort

        CONVENTIONS.merge(
          suffixes: CONVENTIONS[:suffixes].merge(split_bases: bases),
          units: I18n.t('sensor_units'),
          precision: PRECISION,
        )
      end
      private_class_method :conventions_for
    end
  end
end
