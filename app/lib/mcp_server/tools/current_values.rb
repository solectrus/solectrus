module McpServer
  module Tools
    # Returns the latest live reading for each requested sensor (current power
    # flows, battery SOC, temperatures, ...), defaulting to all configured raw
    # sensors. A stale reading (older than a sensor's max_age) or a sensor
    # without data yields a null value, distinct from a measured 0.
    class CurrentValues < Base
      tool_name 'get_current_values'
      title 'Get current sensor values'
      description <<~TEXT.strip
        The most recent live reading of each sensor right now: power flows in
        watts (solar production, grid import/export, house, heatpump, wallbox),
        battery state of charge, temperatures. Without `sensors` every
        configured sensor is returned; with it, exactly those — and only then a
        display_name each, which would be pure weight across the full set. If
        all you need is whether data is still arriving, get_system_info answers
        that in two fields.

        Money sensors (accumulated amounts) and chart-only composites like
        power_balance have no live reading. They are left out of the default set
        and rejected when requested explicitly — see the "c" in each sensor's
        `tools` from list_sensors.

        Freshness metadata makes a null unambiguous:
          - last_seen_at: the sensor's latest data point across its whole
            history, not just the live window. A null value WITH a last_seen_at
            means the source delivered before and is not delivering now —
            offline, or a sensor that only writes sporadically. Only a null
            last_seen_at means it never delivered at all.
          - age_seconds: how long it has been quiet. Present only alongside a
            null value; a reported value is fresh by construction.

        A calculated sensor has no timestamp of its own and reports the newest
        one among its inputs. A measured 0 is a real value, distinct from null.

        Two derived sensors return null deliberately, guarding against reporting
        noise as a number — their source is not missing:
          - self_consumption_quote, while generation is below 50 W: a ratio
            against near-zero generation is noise, not a meaningful 100 %.
          - inverter_power_difference, while the difference is below 5 W or
            below 1 % of generation: that range is sampling noise, not a loss.

        For the same reason two sensors measuring the same thing can disagree by
        a watt live (inverter_power 31 W next to inverter_power_total 32 W):
        each reports its own newest point, and those are not written at the same
        instant. Over a timeframe (get_totals) the skew averages out.
      TEXT
      input_schema(
        properties: {
          sensors: {
            type: 'array',
            items: {
              type: 'string',
            },
            description:
              'Optional list of sensor names. Defaults to all configured sensors.',
          },
        },
      )
      read_only idempotent: false

      def self.call(sensors: nil, **)
        definitions = resolve_sensors(sensors, allow_blank: true)

        if sensors.blank?
          # Default set: only sensors with a meaningful live reading.
          definitions =
            definitions.select { McpServer::SupportedTools.supports?(it, :current) }
        else
          # Explicit request: reject sensors that have no live reading rather
          # than returning a null that reads as "source offline".
          enforce_supported!(definitions, :current)
        end

        data = Sensor::Query::Latest.new(definitions.map(&:name)).call
        last_seen = Freshness.resolve(definitions, data)
        now = Time.current

        # Return exactly the requested sensors (calculated sensors are derived
        # from their raw dependencies internally, but those dependencies are
        # not leaked into the response). A sensor without a fresh reading
        # yields a null value, distinct from a measured 0.
        values =
          definitions.map do |sensor|
            # The live query defines a (possibly nil-returning) accessor for
            # every requested sensor; guard anyway so a missing accessor reads
            # as "no value" rather than raising.
            value = data.respond_to?(sensor.name) ? data.public_send(sensor.name) : nil
            unit = mcp_unit(sensor)
            {
              name: sensor.name,
              **display_name(sensor, sensors),
              value: Precision.round(value, unit),
              unit:,
              **Freshness.metadata(last_seen[sensor], now, value),
            }
          end

        json_response(time: data.time&.iso8601, values:)
      rescue ArgumentError => e
        error_response(e.message)
      end

      # The default set spans every configured sensor, where the human-readable
      # name is pure weight: list_sensors carries it, and a client pulling all
      # values at once is scanning data rather than labelling it. An explicit
      # request is short and usually meant for presentation, so there it stays.
      def self.display_name(sensor, requested)
        return {} if requested.blank?

        { display_name: sensor.display_name }
      end
      private_class_method :display_name

      # A calculated sensor that derives from no inputs (e.g. power_balance, a
      # stacked power-flow balance chart) has no live scalar reading to report:
      # its value is always null. Such sensors are dropped from the default set
      # and rejected when requested explicitly.
      #
      # Public so McpServer::SupportedTools can advertise and enforce the same
      # fact via the `current`/`series` flags in each sensor's supported_tools.
      def self.live_scalarless?(sensor)
        sensor.calculated? && sensor.dependencies.empty?
      rescue ArgumentError
        # A dependency block that needs context kwargs can't be a no-input
        # composite; treat it as a normal sensor.
        false
      end
    end
  end
end
