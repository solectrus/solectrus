module McpServer
  module Tools
    # Discovery tool: lets the client learn which sensors exist and what each
    # one means. Deliberately an index, not a datasheet - the per-sensor
    # datasheet is get_sensor_details.
    class ListSensors < Base
      tool_name 'list_sensors'
      title 'List available sensors'
      description <<~TEXT.strip
        The sensors available on this SOLECTRUS instance (solar inverter,
        battery, grid, house, heatpump, finances, ...). Call this first to
        discover valid sensor names. Per sensor: its name — use these for every
        other tool — a semantic description, and `tools`, which tools return
        meaningful data for it.

        A `display_name` appears wherever the operator named the sensor
        themselves. That is the word the user will use for it, so match their
        wording against it: "Waschmaschine" is custom_power_01, whose name and
        description only ever say "custom consumer 1". Sensors without one are
        named by their description already.

        An index, not a datasheet: unit, category and aggregations for several
        hundred sensors would cost far more context than they are worth up
        front. get_sensor_details returns those for the few you picked, and you
        will rarely need it, because every data tool already reports unit and
        display name for what it returns.

        Sensors ending in "_grid" or "_pv" are NOT listed: they split a base
        sensor by where the energy came from, and say nothing their name and the
        suffix do not. conventions.suffixes names every base sensor that has
        them; the names themselves stay valid input for every tool.

        The `conventions` block explains the suffixes, the `tools` letters, the
        units, and under `precision` how many decimals each unit is rounded to.
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
            'The _grid and _pv variants of a sensor are NOT listed under ' \
              '`sensors`: they split a base sensor by energy source, and on an ' \
              'instance with many consumers they are 40 % of this response ' \
              'without carrying anything their name does not. No sensor ' \
              'outside `split_bases` below carries either suffix. Most of ' \
              'them have both, but where only one direction is meaningful ' \
              'only that one exists, so a name you form off the list is a ' \
              'good guess, not a guarantee. A guess that misses is skipped ' \
              'and reported under `unknown_sensors`, costing its own entry ' \
              'rather than the whole call. Those names are valid ' \
              'input wherever the base sensor is; their tools code is the ' \
              'base\'s without the r. Their meaning is the base sensor\'s ' \
              'description narrowed by the suffix; get_sensor_details spells ' \
              'them out.',
          _grid: 'The share of the base sensor supplied from grid import.',
          _pv: 'The share of the base sensor covered by own PV/solar generation.',
          _total: 'Aggregate across all inverters/consumers of the base sensor.',
        },
        display_name:
          'Present only where the operator named the sensor themselves, and ' \
            'then it is the name the user knows it by - match what they say ' \
            'against it before falling back to the description. Its absence ' \
            'says the sensor carries no name of its own, not that it has none ' \
            'to show: every data tool reports a display name for what it ' \
            'returns, and get_sensor_details for any sensor you ask about.',
        forecast:
          'A sensor whose description says "forecasted" holds predicted, not ' \
            'measured, values, and carries "f" in its tools. get_totals rejects ' \
            'them; use get_forecast for the expected energy, or get_series for ' \
            'the predicted curve.',
        tools:
          'Per sensor, `tools` lists which tools return meaningful data for it, ' \
            'one letter each: c = get_current_values, t = get_totals, ' \
            's = get_series, r = get_ranking, f = get_forecast. A missing c or s ' \
            'is strict - that tool rejects the sensor, because a money sensor or ' \
            'a chart-only composite like power_balance has no live scalar. "c" ' \
            'without "s" means the sensor has a present state but no curve: a ' \
            'boolean or string sensor cannot be averaged into a time bucket, so ' \
            'read it with get_current_values. A missing t or r is advisory: the ' \
            'sensor is outside the primary set, but get_totals may still return ' \
            'a value and get_ranking can still rank any summary-backed sensor. ' \
            'Prefer sensors that carry the letter, but do not read a missing t ' \
            'or r as a hard block.',
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
            'watt_hour it has become, not as a watt. Every value is rounded ' \
            'independently, so an identity between sensors can be off by the ' \
            'last digit - self_consumption may come back 1 Wh away from ' \
            'inverter_power minus grid_export_power. That is the rounding, not ' \
            'an inconsistency in the data; do not report it as one.',
        decimals: McpServer::Precision::DECIMALS,
      }.freeze
      private_constant :PRECISION

      # Suffixes that make a sensor a mechanical split of another one. _total is
      # not among them: it aggregates a family rather than dividing one sensor,
      # and there are only a handful of them.
      SPLIT_SUFFIXES = %w[_grid _pv].freeze
      private_constant :SPLIT_SUFFIXES

      def self.call(**)
        # Force English so the discovery output (descriptions) is deterministic
        # regardless of the instance's locale.
        I18n.with_locale(:en) do
          available = Sensor::Config.sensors
          names = available.to_set(&:name)
          splits, listed = available.partition { split?(it.name, names) }

          json_response(
            sensors: listed.map { entry_for(it) },
            conventions: conventions_for(splits),
          )
        end
      end

      # `display_name` only where the operator set one. Those names are the
      # words the user actually says ("Wie viel zieht die Waschmaschine?"), and
      # no client could map them onto custom_power_01 from its name or its
      # description, both of which only ever say "custom consumer 1". Where no
      # name was set, the label is the sensor's name in prose and would cost
      # bytes to say twice.
      def self.entry_for(sensor)
        {
          name: sensor.name,
          **(sensor.user_defined_name? ? { display_name: sensor.display_name } : {}),
          description: sensor.description,
          tools: McpServer::SupportedTools.code(sensor),
        }
      end
      private_class_method :entry_for

      # The bases are read back off the splits that actually exist rather than
      # assumed symmetric, so a family carrying only one of the two suffixes
      # still lists its base, and exactly once.
      def self.conventions_for(splits)
        bases = splits.to_set { base_name(it.name) }.sort

        CONVENTIONS.merge(
          suffixes: CONVENTIONS[:suffixes].merge(split_bases: bases),
          units: I18n.t('sensor_units'),
          precision: PRECISION,
        )
      end
      private_class_method :conventions_for

      # Recognized by the base sensor actually being listed, not by the name
      # ending in _grid/_pv alone - otherwise a sensor that merely happens to
      # end that way would silently vanish from the index.
      def self.split?(name, names)
        SPLIT_SUFFIXES.any? do |suffix|
          name.end_with?(suffix) && names.include?(:"#{name.to_s.delete_suffix(suffix)}")
        end
      end
      private_class_method :split?

      def self.base_name(name)
        suffix = SPLIT_SUFFIXES.find { name.end_with?(it) }
        name.to_s.delete_suffix(suffix.to_s)
      end
      private_class_method :base_name
    end
  end
end
