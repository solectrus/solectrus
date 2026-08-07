module McpServer
  # Single source of truth for which MCP tools return meaningful data for a
  # given sensor. list_sensors advertises this matrix up front; the data tools
  # (get_series, get_current_values, get_ranking) enforce it, rejecting
  # unsupported sensor/tool combinations instead of silently returning a null
  # series or value.
  #
  # Every flag answers the same question - "does THIS tool answer for this
  # sensor?" - so a client can act on the matrix alone. Where a tool rejects
  # what it cannot answer, the flag is the rejection rule itself, not a
  # separate opinion about it.
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
      return false if McpServer::Tools::CurrentValues.live_scalarless?(sensor)

      numeric?(sensor)
    end

    def supports?(sensor, tool)
      self.for(sensor)[tool]
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
    # this list), and the set get_totals draws its default from.
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

    # Whether get_ranking answers for this sensor - the same predicate
    # Tools::Base#enforce_rankable! rejects on, so the advertised "r" and the
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

    # Whether the value is derived rather than measured.
    #
    # Broader than the domain's `calculated?`, which only knows about a
    # `calculate` block: the _grid halves of a power split carry no block, but
    # nothing measures them either - the Power Splitter service derives them
    # from the base sensor and the grid flow and writes the result back. For a
    # client the distinction that matters is measured vs. derived, and every
    # power_splitter sensor is on the derived side of it.
    def calculated?(sensor)
      sensor.calculated? || sensor.category == :power_splitter
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

      !McpServer::Tools::CurrentValues.live_scalarless?(sensor)
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
