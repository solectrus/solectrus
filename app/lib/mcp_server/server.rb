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
      Read-only data of a SOLECTRUS photovoltaic monitoring system. Call
      list_sensors first: it indexes every sensor name, and the other tools take
      those names. Then get_current_values for live readings, get_totals for a
      timeframe, get_periods for a value per day/week/month/year, get_ranking
      for best/worst periods, get_series for intraday curves;
      get_system_info for installation metadata and currency,
      get_prices for the (time-dependent) tariffs, get_forecast for expected PV
      energy, get_amortization for payback, break-even and NPV/IRR, and
      get_cash_flows for the single investments and costs behind it.

      Units after aggregation, in get_totals and get_ranking:
      #{Facts::WATT_SUM_IS_ENERGY}

      #{Facts::COMPACT_AXIS}

      #{Facts::ROUNDING}

      #{Facts::UNKNOWN_SENSORS}

      #{Facts::TIMEFRAME_NOTE}
    TEXT
    private_constant :INSTRUCTIONS

    # MCP revision 2026-07-28 makes the SEP-2549 cache hints required members
    # of tools/list, but the mcp gem emits them only when they are configured
    # here. A client on that revision rejects the whole tool list without them.
    #
    # The tools are a fixed list with static descriptions, so the response only
    # ever changes with a new release. Five minutes let a client reuse it
    # within a conversation - it weighs ~30 KB - and still pick up a changed
    # list soon after an update.
    # Public, because ResultCompliance states the same policy on the one
    # result the gem leaves without hints.
    CACHE_TTL = 5.minutes
    public_constant :CACHE_TTL

    # `private` because nothing here is shareable across operators, and because
    # it is what the TypeScript and Python SDKs default to.
    CACHE_SCOPE = 'private'.freeze
    public_constant :CACHE_SCOPE

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
