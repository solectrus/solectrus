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
    ].freeze
    private_constant :TOOLS

    INSTRUCTIONS = <<~TEXT.strip
      This server exposes read-only data of a SOLECTRUS photovoltaic monitoring
      system. Call list_sensors first to discover available sensor names and
      units, then use get_current_values for live readings and get_totals for
      aggregated values over a timeframe. get_system_info provides installation
      metadata and the currency; get_prices the (time-dependent) tariffs.
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
