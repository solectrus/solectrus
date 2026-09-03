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

    # The sensors nearly every question is about, with the word a user says for
    # each. Named up front because a model that does not know them either
    # spends a list_sensors round trip on "how much did my PV produce
    # yesterday", or invents a name - pv_production, pv_generation, pv_energy
    # and pv_power all came back rejected in measured runs, each followed by a
    # recovery call. Seven names cost ~60 tokens; the round trip they save
    # costs thousands.
    #
    # The set is filtered by what the instance actually has, because a name
    # promised here and missing there is worse than naming none: the model
    # would ask for it, get an unknown_sensors entry, and trust the rest less.
    CORE_SENSORS = {
      inverter_power: 'PV generation',
      house_power: 'house consumption',
      grid_import_power: 'grid import',
      grid_export_power: 'feed-in',
      battery_soc: 'battery charge',
      heatpump_power: 'heat pump',
      wallbox_power: 'wallbox',
    }.freeze
    private_constant :CORE_SENSORS

    def self.core_sensors
      CORE_SENSORS
        .filter_map do |name, meaning|
          "#{name} (#{meaning})" if Sensor::Config.exists?(name)
        end
        .join(', ')
    end

    # The conventions that hold across every tool, stated here so no tool
    # description has to repeat them (Facts explains why each is said at all).
    #
    # A method rather than a constant, because the core sensors depend on how
    # the instance is configured, and the configuration outlives no boot.
    def self.instructions
      <<~TEXT.strip
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

        The sensors this instance is asked about most, ready to use by name:
        #{core_sensors}. Never invent a name around them - anything else comes
        from list_sensors.

        Units after aggregation, in get_totals and get_ranking:
        #{Facts::WATT_SUM_IS_ENERGY}

        #{Facts::COMPACT_AXIS}

        #{Facts::ROUNDING}

        #{Facts::UNKNOWN_SENSORS}

        #{Facts::TIMEFRAME_NOTE}
      TEXT
    end

    # The SEP-2549 cache hints of tools/list. Without them the gem falls back
    # to the spec default `ttlMs: 0`, which tells a client not to cache at all.
    #
    # The tools are a fixed list with static descriptions, so the response only
    # ever changes with a new release - and a client that reconnects after one
    # reads the new version out of `serverInfo` anyway. It weighs ~28 KB, which
    # a long conversation would otherwise pay several times over, so the hint
    # spans a working session rather than a few turns. An update still reaches
    # a client within the hour, and immediately on its next connect.
    CACHE_TTL = 1.hour
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
        instructions:,
        tools: TOOLS,
        ttl_ms: CACHE_TTL.in_milliseconds,
        cache_scope: CACHE_SCOPE,
        server_context:,
      )
    end
  end
end
