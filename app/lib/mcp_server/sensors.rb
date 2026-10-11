module McpServer
  # The sensors an MCP client can ask about: the configured and permitted
  # ones, without the admin-only sensors. Only the admin sees such a sensor,
  # in the browser (see the `admin_only` DSL).
  module Sensors
    module_function

    def all
      Sensor::Config.sensors.reject(&:admin_only?)
    end
  end
end
