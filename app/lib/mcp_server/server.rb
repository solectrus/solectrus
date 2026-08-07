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
      Tools::Ranking,
      Tools::Series,
      Tools::Forecast,
      Tools::Amortization,
    ].freeze
    private_constant :TOOLS

    INSTRUCTIONS = <<~TEXT.strip
      Read-only data of a SOLECTRUS photovoltaic monitoring system. Call
      list_sensors first: it is a compact index of name, description and which
      tools work for each sensor. get_sensor_details fills in unit, category and
      aggregations for the few you picked, on the rare occasion you need them
      before a call. Then get_current_values for live readings, get_totals for a
      timeframe; get_system_info for installation metadata and currency,
      get_prices for the (time-dependent) tariffs.

      Units after aggregation, in get_totals and get_ranking:
      #{Facts::WATT_SUM_IS_ENERGY}

      #{Facts::ROUNDING}

      #{Facts::UNKNOWN_SENSORS}

      get_totals covers historical actuals only and rejects forecast sensors:
      use get_forecast for the expected PV energy, get_series on a forecast
      sensor for the predicted curve. For the profitability of the whole system
      (payback, break-even, NPV/IRR) use get_amortization.
    TEXT
    private_constant :INSTRUCTIONS

    def self.build(server_context: {})
      MCP::Server.new(
        name: 'solectrus',
        title: 'SOLECTRUS',
        version: Rails.configuration.x.git.commit_version,
        instructions: INSTRUCTIONS,
        tools: TOOLS,
        server_context:,
      )
    end
  end
end
