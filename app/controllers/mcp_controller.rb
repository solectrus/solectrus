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
      MCP::Server::Transports::StreamableHTTPTransport.new(
        server,
        stateless: true,
        # The SDK's DNS rebinding protection validates the Host header (loopback
        # hosts only by default) and the Origin header (same-origin only). It is
        # both unnecessary and incompatible with our design here:
        #   - Access already requires a resource-bound OAuth bearer token over
        #     PKCE with no cookies (see McpOauth), so there is no CSRF/rebinding
        #     vector a browser attacker without the token could exploit.
        #   - We deliberately serve /mcp to any browser Origin (see the CORS
        #     `origins '*'` rule in config/initializers/rack.rb) so that web AI
        #     clients like claude.ai can call it. Origin validation would 403
        #     exactly those clients, and we cannot enumerate their origins.
        # Allow-listing our own host (e.g. via APP_HOST) would only satisfy the
        # Host check; the Origin check would still 403 those browser clients, and
        # their origins cannot be enumerated. So we turn the whole thing off.
        dns_rebinding_protection: false,
      )

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
    # `\S` anchors the capture so it cannot overlap with the preceding `\s+`,
    # which would allow quadratic backtracking (ReDoS) on crafted headers.
    request.authorization.to_s[/\ABearer\s+(\S.*)\z/i, 1]
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
