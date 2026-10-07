module McpServer
  # The sensors an MCP client can ask about: the configured and permitted
  # ones, without the personal sensors. Only the admin sees a personal
  # sensor, in the browser (see the `personal` DSL).
  module Sensors
    module_function

    def all
      Sensor::Config.sensors.reject(&:personal?)
    end
  end
end
