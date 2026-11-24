module McpServer
  # The sensors an MCP client can ask about: the configured and permitted
  # ones. The admin-only sensors hold a location, which only the admin sees
  # in the browser (see the `admin_only` DSL). MCP offers them only while the
  # admin allows locations for MCP (Setting.mcp_locations).
  module Sensors
    module_function

    def all
      sensors = Sensor::Config.sensors
      locations? ? sensors : sensors.reject(&:admin_only?)
    end

    def locations? = Setting.mcp_locations

    # { [measurement, field] => sensor name } of #all. The sensor tools answer
    # such a field with unit and summaries, so the raw data tools name it.
    def by_field
      lookup(all).transform_values(&:first)
    end

    # The [measurement, field] pairs of the admin-only sensors, which the raw
    # data tools withhold for the same reason, unless locations are allowed.
    # Configured counts, permitted or not.
    def withheld_fields
      return Set.new if locations?

      admin_only = Sensor::Registry.all.select { it.admin_only? && Sensor::Config.configured?(it.name) }
      lookup(admin_only).keys.to_set
    end

    def lookup(sensors) = Sensor::Query::Helpers::Influx::SensorFilter.lookup(sensors.map(&:name))
  end
end
