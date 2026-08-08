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
        Metadata about this SOLECTRUS installation, as background before
        interpreting values:
          - installation_date: bounds the "all" timeframe.
          - currency (ISO-4217) and timezone — all timestamps and all
            day/week/month boundaries follow that timezone.
          - installed_peak_power_kwp: installed PV peak power, if known.
          - has_battery / has_wallbox / has_heatpump / has_forecast: which
            subsystems are configured, derived from the actual sensor setup.
          - data: when this installation last received anything (last_seen_at,
            age_seconds; null only if it never received anything at all). This
            is the health check "is data still arriving?" — seconds old means
            live, anything beyond that means the collector is behind or down,
            and age_seconds says for how long.

        Tariffs are in get_prices. Values that cannot be reliably derived (e.g.
        installed_peak_power_kwp on an unregistered instance) are omitted rather
        than guessed.
      TEXT
      input_schema(properties: {})
      # `data` is a live reading, so an identical call does not return an
      # identical result.
      read_only idempotent: false

      def self.perform(**)
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

        info
      end

      def self.configured?(sensor_name)
        Sensor::Config.exists?(sensor_name)
      end
      private_class_method :configured?

      def self.data_freshness
        last_seen = last_delivery

        {
          last_seen_at: last_seen&.iso8601,
          age_seconds: last_seen ? (Time.current - last_seen).round : nil,
        }
      end
      private_class_method :data_freshness

      # The newest data point across all sensors that have a live reading -
      # one query, two fields, and the client is spared pulling ~70 values
      # just to find out whether anything is still being written.
      #
      # That query looks back a day and no further, which is right for the
      # dashboard it was built for and wrong here: an installation quiet for
      # longer has nothing in it, so a null would report "never received any
      # data" about the very outage this field exists to surface - and the
      # longer the outage lasts, the more confident the wrong answer becomes.
      # An empty live window, and only that, is therefore worth the scan back
      # to the installation date. A delivering instance never reaches it.
      def self.last_delivery
        live = Sensor::Config.sensors.select { McpServer::SupportedTools.supports?(it, :current) }
        return if live.empty?

        names = live.map(&:name)
        Sensor::Query::Latest.new(names).call.time ||
          Sensor::Query::LastSeen.new(names).call.values.compact.max
      end
      private_class_method :last_delivery
    end
  end
end
