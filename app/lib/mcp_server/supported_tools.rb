module McpServer
  # Single source of truth for which MCP tools return meaningful data for a
  # given sensor. list_sensors advertises this matrix up front; the data tools
  # enforce it, rejecting unsupported sensor/tool combinations instead of
  # silently returning a null series or value.
  #
  # Every flag answers the same question - "does THIS tool answer for this
  # sensor?" - so a client can act on the matrix alone, and every flag is the
  # rejection rule itself rather than a separate opinion about it. The reverse
  # is not promised: a sensor carrying a flag can still come back null where
  # its own calculation suppresses a result (inverter_power_difference below
  # 1 % of generation), which is a per-value condition no static flag states.
  module SupportedTools
    module_function

    # The matrix exposed per sensor in list_sensors.
    def for(sensor)
      live = live?(sensor)

      {
        current: live,
        totals: !sensor.forecast? && aggregations(sensor).any?,
        series: curve?(sensor),
        ranking: rankable?(sensor),
        forecast: sensor.forecast?,
      }
    end

    # Whether get_series returns a meaningful curve.
    #
    # Deliberately NOT tied to #live?. The two questions only look alike: a
    # curve is a sequence of periods, and a power split divides periods
    # (Facts::SPLIT_CADENCE) - it just cannot divide an instant. So a split
    # keeps its "s" while losing its "c", and get_series carries the one
    # condition the letter cannot express by rejecting a timeframe that has not
    # ended yet (Tools::Series).
    #
    # What is out here has no periods to show either: Facts::MONEY_ACCUMULATED,
    # Facts::CHART_ONLY and Facts::NON_AGGREGATABLE.
    def curve?(sensor)
      return false if sensor.unit == :money
      return false if sensor.chart_only?

      numeric?(sensor)
    end

    def supports?(sensor, tool)
      self.for(sensor)[tool]
    end

    # The tools that DO answer for this sensor, minus the one that just
    # rejected it. Every rejection message composes its "what to ask instead"
    # from this rather than naming a tool from memory.
    #
    # A hard-coded suggestion is right for the sensor its author had in mind
    # and wrong for the next one: "Use get_current_values or get_series" sent a
    # client asking for power_balance to two tools that reject it as well, and
    # nothing in the code could notice, because the sentence was a string. An
    # empty result is an answer too - for some sensors nothing answers.
    def alternatives(sensor, except: nil)
      matrix = self.for(sensor)

      LETTERS.each_key.select { |tool| matrix[tool] && tool != except }
    end

    # WHY a tool has no data for this sensor, as a key the caller turns into
    # prose - or nil where the tool does answer.
    #
    # It lives here, next to the predicates it mirrors, so a reason cannot
    # contradict the flag it explains: both walk the same conditions in the
    # same order. Stating the reasons in the rejecting tool instead is what
    # made it a catch-all, listing every reason a sensor could have been
    # rejected for - which sent a client asking for power_balance to
    # get_totals, a tool that rejects it too.
    def rejection(sensor, tool)
      case tool
      when :series then series_rejection(sensor)
      when :current then current_rejection(sensor)
      when :totals then totals_rejection(sensor)
      when :ranking then ranking_rejection(sensor)
      end
    end

    def series_rejection(sensor)
      return :money if sensor.unit == :money
      return :chart_only if sensor.chart_only?

      :non_aggregatable unless numeric?(sensor)
    end

    def current_rejection(sensor)
      return :money if sensor.unit == :money
      return :split unless sensor.instantaneous?

      :chart_only if sensor.chart_only?
    end

    # Mirrors the `totals` flag: a forecast first, since that is the reason a
    # client can act on (get_forecast exists), and only then the absence of an
    # aggregation, which is a property of the sensor rather than of the ask.
    def totals_rejection(sensor)
      return :forecast if sensor.forecast?

      :no_aggregation if aggregations(sensor).empty?
    end

    # Mirrors the `ranking` flag, in the order the two reasons refine each
    # other: a sensor with no aggregation at all has nothing to order by, which
    # is more specific than "the summaries do not store it" - and answering the
    # latter would send a client looking for a summary that would not help.
    def ranking_rejection(sensor)
      return :no_aggregation if aggregations(sensor).empty?

      :not_summarized unless rankable?(sensor)
    end

    # One letter per tool, for the compact `tools` field.
    LETTERS = {
      current: 'c',
      totals: 't',
      series: 's',
      ranking: 'r',
      forecast: 'f',
    }.freeze
    public_constant :LETTERS

    # The matrix as a compact code, e.g. "ctsr". Spelling five booleans out per
    # sensor cost ~97 bytes and a quarter of the whole list_sensors response -
    # for seven distinct combinations across ~200 sensors. The letters are
    # explained once, in the conventions block.
    def code(sensor)
      matrix = self.for(sensor)

      LETTERS.filter_map { |tool, letter| letter if matrix[tool] }.join
    end

    # One meaning, everywhere it appears: the values get_ranking accepts for its
    # `aggregation` parameter (Sensor::Query::Ranking validates against exactly
    # this list), and the set get_totals draws its default from. An empty list
    # is therefore what clears both the `t` and the `r` flag, and what both
    # tools reject on - there is no per-period value.
    #
    # It used to be reported as empty for forecast sensors, on the grounds that
    # get_totals rejects them - which made the field answer two questions at
    # once and neither of them well: get_ranking does rank a forecast sensor,
    # with the aggregation the list denied it had. Whether get_totals answers
    # for a sensor is what the `t` flag says; this field says what to pass.
    def aggregations(sensor)
      sensor.allowed_aggregations
    end

    # The one of them get_totals applies when it is not told otherwise, and
    # get_ranking's default. Reported alongside the list so a client knows what
    # a call will return rather than only what it could ask for.
    def default_aggregation(sensor)
      sensor.default_aggregation
    end

    # Whether get_ranking answers for this sensor. The tool enforces the flag
    # itself (Tools::Base#enforce_supported!), so the advertised "r" and the
    # tool's behaviour cannot disagree.
    #
    # This is NOT the curated Top 10 set the SOLECTRUS UI offers: get_ranking
    # ranks every sensor the summaries back, `top10` merely marks the handful
    # the UI puts on a chart. Advertising the curated set here made "r" mean
    # something no client could use, since a missing one said nothing about
    # whether the call would work.
    def rankable?(sensor)
      sensor.rankable? && !sensor.default_aggregation.nil?
    end

    # Whether the value is derived rather than measured. One question, and the
    # answer a client needs: may I treat this number as a reading, or is it the
    # result of arithmetic over other sensors?
    #
    # Broader than the domain's `calculated?`, which only knows about a Ruby
    # `calculate` block. Two families carry no such block and are derived all
    # the same:
    #   - the economic sensors, whose money comes from an energy multiplied by
    #     a tariff. Nothing meters a cost. Most of them state that arithmetic
    #     as SQL over the summaries (`sql_calculated?`) rather than as a Ruby
    #     block, and reporting those as measured was the plain opposite of what
    #     they are.
    #   - the _grid halves of a power split. The Power Splitter service derives
    #     them from the base sensor and the grid flow and writes the result
    #     back, so every power_splitter sensor is on the derived side.
    def calculated?(sensor)
      sensor.calculated? || sensor.sql_calculated? || sensor.category == :power_splitter
    end

    # Whether the sensor has a meaningful instantaneous reading (drives the
    # current/series flags). Three kinds have none: Facts::MONEY_ACCUMULATED,
    # a power split (Facts::SPLIT_CADENCE, decided by
    # Sensor::Definitions::Base#instantaneous?) and Facts::CHART_ONLY.
    #
    # The whole SOLECTRUS UI has always hidden the split in its "now" views;
    # MCP was the one surface still handing it out as a live watt reading,
    # subtracted from a base sensor sampled seconds ago.
    def live?(sensor)
      return false if sensor.unit == :money
      return false unless sensor.instantaneous?

      !sensor.chart_only?
    end

    # Units InfluxDB cannot fold into a time bucket. A live reading of such a
    # sensor is perfectly meaningful - "is the car plugged in", "what is the
    # heat pump doing" - and get_current_values reports it; the mean/min/max
    # over a bucket that get_series would ask for is not, and aggregateWindow
    # rejects the column outright ("unsupported aggregate column type bool").
    # So these sensors are live but curve-less: `c` without `s`.
    NON_AGGREGATABLE_UNITS = %i[boolean string].freeze
    private_constant :NON_AGGREGATABLE_UNITS

    def numeric?(sensor)
      NON_AGGREGATABLE_UNITS.exclude?(sensor.unit)
    end
  end
end
