# Model Context Protocol endpoint. Exposes read-only sensor data to MCP clients
# (Claude Desktop, Claude Code, ...) via stateless Streamable HTTP.
#
# Deliberately an ActionController::API subclass, so it does NOT inherit the
# session/registration/sponsoring before_actions of ApplicationController.
#
# Access control:
#   - MCP is a sponsor-only feature; without an active sponsorship the
#     endpoint is invisible (404), regardless of the setting.
#   - When disabled (Setting.mcp_enabled false), the endpoint is invisible (404).
#   - When available, every request must carry the bearer token from the
#     settings (Authorization: Bearer <Setting.mcp_token>), otherwise 401.
class McpController < ActionController::API
  def handle
    return head :not_found unless mcp_available?
    return request_authentication unless authenticated?

    server = McpServer::Server.build
    transport =
      MCP::Server::Transports::StreamableHTTPTransport.new(server, stateless: true)

    request.body.rewind
    status, headers, body = transport.handle_request(request)

    headers.each { |key, value| response.set_header(key, value) }
    render status:, body: Array(body).join
  end

  private

  def mcp_available?
    Setting.mcp_enabled && ApplicationPolicy.mcp?
  end

  def authenticated?
    expected = Setting.mcp_token.to_s
    provided = bearer_token.to_s

    expected.present? && provided.present? &&
      ActiveSupport::SecurityUtils.secure_compare(provided, expected)
  end

  def bearer_token
    request.authorization.to_s[/\ABearer\s+(.+)\z/i, 1]
  end

  def request_authentication
    response.set_header('WWW-Authenticate', 'Bearer realm="SOLECTRUS MCP"')
    head :unauthorized
  end
end
