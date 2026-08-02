module McpServer
  # Single source of truth for which MCP tools return meaningful data for a
  # given sensor. list_sensors advertises this matrix up front; the data tools
  # (get_series, get_current_values) enforce it, rejecting unsupported
  # sensor/tool combinations instead of silently returning a null series or
  # value.
  module SupportedTools
    module_function

    # The matrix exposed per sensor in list_sensors.
    def for(sensor)
      live = live?(sensor)

      {
        current: live,
        totals: aggregations(sensor).any?,
        series: live && numeric?(sensor),
        ranking: sensor.top10_enabled? && sensor.top10_permitted?,
        forecast: sensor.forecast?,
      }
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

    # The aggregations a client can actually use across the MCP tools. Forecast
    # sensors are rejected by get_totals, so their stored aggregation is usable
    # nowhere - report none (the `forecast` convention documents how to read
    # them instead).
    def aggregations(sensor)
      return [] if sensor.forecast?

      sensor.allowed_aggregations
    end

    # Whether the sensor has a meaningful instantaneous reading (drives the
    # current/series flags).
    #
    #   - Money sensors are accumulated amounts (costs, revenue). They have no
    #     instantaneous live scalar, and a per-bucket "mean" curve would be
    #     meaningless, so they are totals-only - read them with get_totals over
    #     a timeframe.
    #   - Chart-only composites with no inputs (e.g. power_balance) likewise
    #     have no live scalar and return null there.
    def live?(sensor)
      return false if sensor.unit == :money

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
