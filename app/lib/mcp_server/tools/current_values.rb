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
        battery state of charge, temperatures. With `sensors`, exactly those —
        and only then a display_name each, which would be pure weight across a
        large set. If all you need is whether data is still arriving,
        get_system_info answers that in two fields.

        Without `sensors` you get every configured sensor that HAS a live
        reading. Money sensors, the _grid/_pv power splits and chart-only
        composites have none: they carry no "c" in their `tools`, stay out of
        the default set, and naming one is an error that says what to ask
        instead.

        Every entry carries `last_seen_at` and `age_seconds` — for a reported
        value as much as for a null one:
          - last_seen_at: when that sensor last delivered anything, across its
            whole history rather than the live window. A null value WITH a
            last_seen_at means the source delivered before and is not
            delivering now — offline, or writing only sporadically. Only a null
            last_seen_at means it never delivered at all.
          - age_seconds: how old that reading is. "Live" only means "within the
            sensor's max_age" (15 min for most, 2 h for the sparse ones), so
            two values here can describe states minutes apart — compare their
            ages before comparing them. The top-level `time` is the newest of
            them, not an instant they share, and the same skew is why two
            sensors measuring the same thing can differ by a watt
            (inverter_power 31 W next to inverter_power_total 32 W). Over a
            timeframe (get_totals) it averages out.

        A calculated sensor has no timestamp of its own and reports the newest
        one among its inputs. A measured 0 is a real value, distinct from null.

        Two derived sensors return null deliberately rather than report noise
        as a number — their source is not missing: self_consumption_quote below
        50 W of generation (a ratio against near-zero generation is not a
        meaningful 100 %), and inverter_power_difference below 5 W or below 1 %
        of generation (sampling noise, not a loss).
      TEXT
      input_schema(
        properties: {
          sensors:
            sensors_property(
              'Optional list of sensor names. Defaults to every configured ' \
                'sensor that has a live reading.',
              required: false,
            ),
        },
      )
      read_only idempotent: false

      def self.perform(sensors: nil, **)
        definitions, unknown = resolve_sensors(sensors, allow_blank: true)

        if sensors.blank?
          # Default set: only sensors with a meaningful live reading. That
          # drops the _grid/_pv splits too, which is also what keeps this
          # response from roughly doubling on an instance with many consumers.
          definitions =
            definitions.select { McpServer::SupportedTools.supports?(it, :current) }
        else
          # Explicit request: reject sensors that have no live reading rather
          # than returning a null that reads as "source offline".
          enforce_supported!(definitions, :current, unknown)
        end

        data = Sensor::Query::Latest.new(definitions.map(&:name)).call
        last_seen = Freshness.resolve(definitions, data)
        now = Time.current

        # Return exactly the requested sensors (calculated sensors are derived
        # from their raw dependencies internally, but those dependencies are
        # not leaked into the response). A sensor without a fresh reading
        # yields a null value, distinct from a measured 0.
        values = definitions.map { value_for(it, data, last_seen, now, sensors) }

        { time: data.time&.iso8601, **unknown_sensors_note(unknown), values: }
      end

      # One sensor's entry: its value, the unit it carries and the freshness
      # metadata that makes a null unambiguous.
      def self.value_for(sensor, data, last_seen, now, requested)
        # The live query defines a (possibly nil-returning) accessor for every
        # requested sensor; guard anyway so a missing accessor reads as "no
        # value" rather than raising.
        value = data.respond_to?(sensor.name) ? data.public_send(sensor.name) : nil
        unit = mcp_unit(sensor)

        {
          name: sensor.name,
          **display_name(sensor, requested),
          value: Precision.round(value, unit),
          unit:,
          **Freshness.metadata(last_seen[sensor], now),
        }
      end
      private_class_method :value_for

      # The default set spans every configured sensor, where the human-readable
      # name is pure weight: list_sensors carries it, and a client pulling all
      # values at once is scanning data rather than labelling it. An explicit
      # request is short and usually meant for presentation, so there it stays.
      def self.display_name(sensor, requested)
        return {} if requested.blank?

        { display_name: mcp_display_name(sensor) }
      end
      private_class_method :display_name
    end
  end
end
