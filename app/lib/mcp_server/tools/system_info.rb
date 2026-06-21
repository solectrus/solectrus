module McpServer
  module Tools
    # Static-ish context about this SOLECTRUS installation: installation date,
    # currency and timezone. Lets the client interpret values (money, lifetime
    # "all" timeframes, ...) instead of guessing.
    class SystemInfo < Base
      tool_name 'get_system_info'
      title 'Get system information'
      description <<~TEXT.strip
        Get metadata about this SOLECTRUS installation: installation date,
        currency (ISO-4217) and timezone. Useful as background context before
        interpreting values - e.g. the installation date bounds the "all"
        timeframe, and the currency applies to every monetary value returned by
        the other tools.
      TEXT
      input_schema(properties: {})
      read_only idempotent: true

      def self.call(**)
        json_response(
          installation_date: Rails.configuration.x.installation_date.iso8601,
          currency: Rails.configuration.x.currency,
          timezone: Time.zone.name,
        )
      end
    end
  end
end
