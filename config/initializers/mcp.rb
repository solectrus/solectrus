# Configure the Model Context Protocol server (gem "mcp").
#
# The Streamable HTTP transport rescues exceptions raised while handling a
# request and forwards them to the configured exception_reporter. Its default
# is a no-op, which would silently swallow tool errors in production. Route
# them to the regular logger and to Honeybadger (when enabled).
MCP.configure do |config|
  config.exception_reporter = lambda do |exception, server_context|
    Rails.logger.error("[MCP] #{exception.class}: #{exception.message}")

    if defined?(Honeybadger)
      Honeybadger.notify(exception, context: { mcp_server_context: server_context })
    end
  end
end
