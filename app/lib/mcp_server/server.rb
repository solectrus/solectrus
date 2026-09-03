module McpServer
  # Builds the MCP::Server instance exposing SOLECTRUS' read-only data tools.
  # A fresh server is created per request (stateless transport).
  module Server
    TOOLS = [
      Tools::ListSensors,
      Tools::SensorDetails,
      Tools::SystemInfo,
      Tools::Prices,
      Tools::CurrentValues,
      Tools::Totals,
      Tools::Periods,
      Tools::Ranking,
      Tools::Series,
      Tools::Forecast,
      Tools::Amortization,
      Tools::CashFlows,
    ].freeze
    private_constant :TOOLS

    # The conventions that hold across every tool, stated here so no tool
    # description has to repeat them (Facts explains why each is said at all).
    INSTRUCTIONS = <<~TEXT.strip
      Read-only data of a SOLECTRUS photovoltaic monitoring system.
      get_current_values for live readings, get_totals for a
      timeframe, get_periods for a value per day/week/month/year, get_ranking
      for best/worst periods, get_series for intraday curves;
      get_system_info for installation metadata and currency,
      get_prices for the (time-dependent) tariffs, get_forecast for expected PV
      energy, get_amortization for payback, break-even and NPV/IRR, and
      get_cash_flows for the single investments and costs behind it.

      list_sensors is for DISCOVERY alone: call it to learn which sensors
      exist, or to resolve a sensor the user named. It is not a prerequisite -
      when you already know the sensor name, call the data tool directly.

      Units after aggregation, in get_totals and get_ranking:
      #{Facts::WATT_SUM_IS_ENERGY}

      #{Facts::COMPACT_AXIS}

      #{Facts::ROUNDING}

      #{Facts::UNKNOWN_SENSORS}

      #{Facts::TIMEFRAME_NOTE}
    TEXT
    private_constant :INSTRUCTIONS

    # The SEP-2549 cache hints of tools/list. Without them the gem falls back
    # to the spec default `ttlMs: 0`, which tells a client not to cache at all.
    #
    # The tools are a fixed list with static descriptions, so the response only
    # ever changes with a new release. Five minutes let a client reuse it
    # within a conversation - it weighs ~30 KB - and still pick up a changed
    # list soon after an update.
    CACHE_TTL = 5.minutes
    private_constant :CACHE_TTL

    # `private` because nothing here is shareable across operators, and because
    # it is what the TypeScript and Python SDKs default to.
    CACHE_SCOPE = 'private'.freeze
    private_constant :CACHE_SCOPE

    def self.build(server_context: {})
      MCP::Server.new(
        name: 'solectrus',
        title: 'SOLECTRUS',
        version: Rails.configuration.x.git.commit_version,
        instructions: INSTRUCTIONS,
        tools: TOOLS,
        ttl_ms: CACHE_TTL.in_milliseconds,
        cache_scope: CACHE_SCOPE,
        server_context:,
      )
    end
  end
end
