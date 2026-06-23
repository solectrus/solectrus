module McpServer
  module Tools
    # Static-ish context about this SOLECTRUS installation: installation date,
    # currency and timezone. Lets the client interpret values (money, lifetime
    # "all" timeframes, ...) instead of guessing.
    class SystemInfo < Base
      tool_name 'get_system_info'
      title 'Get system information'
      description <<~TEXT.strip
        Get metadata about this SOLECTRUS installation, as background context
        before interpreting values:
          - installation_date: bounds the "all" timeframe.
          - currency (ISO-4217) and timezone.
          - installed_peak_power_kwp: installed PV peak power (only if known).
          - has_battery / has_wallbox / has_heatpump / has_forecast: which
            subsystems are configured, derived from the actual sensor setup.

        For the (time-dependent) electricity and feed-in tariffs, use
        get_prices. Only values that can be reliably derived from configuration
        or data are returned; unknown ones (e.g. installed_peak_power_kwp on an
        unregistered instance) are omitted rather than guessed.
      TEXT
      input_schema(properties: {})
      read_only idempotent: true

      def self.call(**)
        info = {
          installation_date: Rails.configuration.x.installation_date.iso8601,
          currency: Rails.configuration.x.currency,
          timezone: Time.zone.name,
          has_battery: configured?(:battery_soc) || configured?(:battery_power),
          has_wallbox: configured?(:wallbox_power),
          has_heatpump: configured?(:heatpump_power),
          has_forecast: configured?(:inverter_power_forecast),
        }

        # Only known from the (remote) registration; omit when unavailable
        # rather than reporting a guessed/zero peak power.
        kwp = UpdateCheck.kwp&.to_f
        info[:installed_peak_power_kwp] = kwp if kwp&.positive?

        json_response(**info)
      end

      def self.configured?(sensor_name)
        Sensor::Config.exists?(sensor_name)
      end
      private_class_method :configured?
    end
  end
end
