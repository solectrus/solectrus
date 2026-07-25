module McpServer
  module Tools
    # Static-ish context about this SOLECTRUS installation: installation date,
    # currency and timezone. Lets the client interpret values (money, lifetime
    # "all" timeframes, ...) instead of guessing. Plus the one moving part
    # worth asking about up front: whether data is still arriving.
    class SystemInfo < Base
      tool_name 'get_system_info'
      title 'Get system information'
      description <<~TEXT.strip
        Get metadata about this SOLECTRUS installation, as background context
        before interpreting values:
          - installation_date: bounds the "all" timeframe.
          - currency (ISO-4217) and timezone. All timestamps and all
            day/week/month boundaries follow that timezone.
          - installed_peak_power_kwp: installed PV peak power (only if known).
          - has_battery / has_wallbox / has_heatpump / has_forecast: which
            subsystems are configured, derived from the actual sensor setup.
          - data: when this installation last received anything at all
            (last_seen_at, age_seconds; null before the very first data point).
            Use it as the health check "is data still arriving?" — seconds old
            means live, minutes or more means the data collector is behind or
            down — instead of pulling every live value with get_current_values
            just to read their timestamps.

        For the (time-dependent) electricity and feed-in tariffs, use
        get_prices. Only values that can be reliably derived from configuration
        or data are returned; unknown ones (e.g. installed_peak_power_kwp on an
        unregistered instance) are omitted rather than guessed.
      TEXT
      input_schema(properties: {})
      # `data` is a live reading, so an identical call does not return an
      # identical result.
      read_only idempotent: false

      def self.call(**)
        info = {
          installation_date: Rails.configuration.x.installation_date.iso8601,
          currency: Rails.configuration.x.currency,
          timezone: Time.zone.name,
          has_battery: configured?(:battery_soc) || configured?(:battery_power),
          has_wallbox: configured?(:wallbox_power),
          has_heatpump: configured?(:heatpump_power),
          has_forecast: configured?(:inverter_power_forecast),
          data: data_freshness,
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

      # The newest data point across all sensors that have a live reading -
      # one query, two fields, and the client is spared pulling ~70 values
      # just to find out whether anything is still being written.
      def self.data_freshness
        live = Sensor::Config.sensors.select { McpServer::SupportedTools.supports?(it, :current) }
        last_seen = live.any? ? Sensor::Query::Latest.new(live.map(&:name)).call.time : nil

        {
          last_seen_at: last_seen&.iso8601,
          age_seconds: last_seen ? (Time.current - last_seen).round : nil,
        }
      end
      private_class_method :data_freshness
    end
  end
end
