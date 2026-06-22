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
#   - When available, every request must carry a valid OAuth access token
#     (Authorization: Bearer <access_token>) we issued, otherwise 401. See
#     McpOauth for the stateless OAuth 2.1 (auth code + PKCE) flow.
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
    McpOauth.available?
  end

  def authenticated?
    token = bearer_token
    token.present? &&
      McpOauth.valid_access_token?(token, base_url: request.base_url).present?
  end

  # Tokens are only ever read from the Authorization header, never from the
  # query string (forbidden by the MCP spec).
  def bearer_token
    request.authorization.to_s[/\ABearer\s+(.+)\z/i, 1]
  end

  # Point unauthenticated clients at the protected-resource metadata so they
  # can discover the authorization server and start the OAuth flow (RFC 9728).
  def request_authentication
    metadata_url = McpOauth.protected_resource_metadata_url(request.base_url)
    response.set_header(
      'WWW-Authenticate',
      %(Bearer resource_metadata="#{metadata_url}"),
    )
    head :unauthorized
  end
end
