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
      This server exposes read-only data of a SOLECTRUS photovoltaic monitoring
      system. Call list_sensors first to discover available sensor names - it
      returns a compact index (name, description, and which tools work for each
      sensor); get_sensor_details fills in unit, category and aggregations for
      the few sensors you picked, on the rare occasion you need them before
      making a call. Then use get_current_values for live readings and
      get_totals for aggregated values over a timeframe. get_system_info
      provides installation metadata, currency and which subsystems exist;
      get_prices the (time-dependent) tariffs.

      Units after aggregation: summing a power sensor (unit "watt") yields an
      energy, so in get_totals/get_ranking the resulting `value` is in Wh, not
      W (divide by 1000 for kWh) - don't read a watt-sum as a power.

      Every value is rounded by its unit alone, identically in every tool, so
      the same sensor never comes back rounded from one tool and unrounded from
      another. list_sensors publishes the exact decimals per unit in
      conventions.precision.

      get_totals covers historical actuals only and rejects forecast sensors.
      For the expected PV generation (what's still coming today, per upcoming
      day) use get_forecast; for the predicted power curve use get_series on a
      forecast sensor (e.g. inverter_power_forecast).

      For the profitability of the whole system - when the investment pays off,
      break-even, NPV/IRR - use get_amortization (it combines the measured
      savings with the manually kept cash flow register).
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
