# Shared gate for the MCP OAuth + discovery endpoints. When MCP is not
# available (toggle off or non-sponsor), every endpoint behaves as 404, so the
# whole OAuth surface is invisible - exactly like the /mcp endpoint itself.
module McpOauthGated
  extend ActiveSupport::Concern

  included { before_action :ensure_mcp_oauth_available }

  private

  def ensure_mcp_oauth_available
    head :not_found unless McpOauth.available?
  end

  # Issuer/resource URLs are derived from the actual request host, so the same
  # values the client discovered are the ones we sign and verify against. No
  # host is ever hardcoded.
  def oauth_base_url
    request.base_url
  end
end
