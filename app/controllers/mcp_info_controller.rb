# Human-facing landing page for the MCP endpoint. The Model Context Protocol
# itself is served at POST /mcp (see McpController); a browser hitting GET /mcp
# would otherwise get a bare 404. Show a short guide on how to connect an AI
# client instead - but only when MCP is actually available, so the feature
# stays invisible when disabled or for non-sponsors (same gate as /mcp).
#
# Inherits ApplicationController to reuse admin? and the app chrome, including
# the registration/sponsoring nag redirects (this info page is not essential,
# so the nag takes precedence). Only the admin (who configures MCP) may see the
# page; everyone else gets a 404, so it never reveals to anonymous visitors that
# MCP is available here.
class McpInfoController < ApplicationController
  before_action :answer_mcp_client
  before_action :ensure_admin_and_mcp_available

  layout 'blank'

  private

  # An MCP client asking for the GET stream is not a browser looking for a
  # guide. Streamable HTTP requires 405 where a server offers no such stream,
  # so it stops waiting for one; a 404 reads as "wrong URL" and sends it
  # rediscovering an endpoint that is right here. Recognised by the Accept
  # header, the one thing that separates the two callers on the same path.
  def answer_mcp_client
    return unless request.accepts.any? { |type| type.to_s == 'text/event-stream' }
    return head :not_found unless McpOauth.available?

    response.set_header('Allow', 'POST')
    head :method_not_allowed
  end

  # 404 (not 403) so the page never reveals whether MCP is enabled here.
  def ensure_admin_and_mcp_available
    head :not_found unless McpOauth.available? && admin?
  end

  helper_method def title
    t('mcp_info.title')
  end
end
