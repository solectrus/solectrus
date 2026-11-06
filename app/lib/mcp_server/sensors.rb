module McpServer
  # The sensors an MCP client can ask about: the configured and permitted
  # ones, without the admin-only sensors. Only the admin sees such a sensor,
  # in the browser (see the `admin_only` DSL).
  module Sensors
    module_function

    def all
      Sensor::Config.sensors.reject(&:admin_only?)
    end

    # { [measurement, field] => sensor name } of #all. The sensor tools answer
    # such a field with unit and summaries, so the raw data tools name it.
    def by_field
      lookup(all).transform_values(&:first)
    end

    # The [measurement, field] pairs of the admin-only sensors, which the raw
    # data tools withhold for the same reason. Configured counts, permitted
    # or not.
    def withheld_fields
      admin_only = Sensor::Registry.all.select { it.admin_only? && Sensor::Config.configured?(it.name) }
      lookup(admin_only).keys.to_set
    end

    def lookup(sensors) = Sensor::Query::Helpers::Influx::SensorFilter.lookup(sensors.map(&:name))
  end
end
