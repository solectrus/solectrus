module McpServer
  # Builds the MCP::Server instance exposing SOLECTRUS' read-only data tools.
  # A fresh server is created per request (stateless transport).
  module Server
    TOOLS = [
      Tools::ListSensors,
      Tools::SystemInfo,
      Tools::Prices,
      Tools::CurrentValues,
      Tools::Totals,
      Tools::Ranking,
      Tools::Series,
      Tools::Forecast,
    ].freeze
    private_constant :TOOLS

    INSTRUCTIONS = <<~TEXT.strip
      This server exposes read-only data of a SOLECTRUS photovoltaic monitoring
      system. Call list_sensors first to discover available sensor names and
      units, then use get_current_values for live readings and get_totals for
      aggregated values over a timeframe. get_system_info provides installation
      metadata, currency and which subsystems exist; get_prices the
      (time-dependent) tariffs.

      Units after aggregation: summing a power sensor (unit "watt") yields an
      energy, so in get_totals/get_ranking the resulting `value` is in Wh, not
      W (divide by 1000 for kWh) - don't read a watt-sum as a power.

      get_totals covers historical actuals only and rejects forecast sensors.
      For the expected PV generation (what's still coming today, per upcoming
      day) use get_forecast; for the predicted power curve use get_series on a
      forecast sensor (e.g. inverter_power_forecast).
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
