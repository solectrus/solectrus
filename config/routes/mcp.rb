# Model Context Protocol endpoint for read-only data access by AI clients,
# plus the OAuth 2.1 server protecting it. Drawn from config/routes.rb.

# Disabled unless enabled in the settings; requires an OAuth access token.
post '/mcp', to: 'mcp#handle'
# A browser opening the endpoint (GET) would otherwise hit a bare 404. Show a
# short guide on how to connect an AI client instead - gated the same way, so
# it stays invisible when MCP is disabled or for non-sponsors.
get '/mcp', to: 'mcp_info#show'
# Streamable HTTP also defines DELETE (session termination). This transport is
# stateless and has no session to terminate, and the spec asks for 405 rather
# than a 404 that reads as "no endpoint here". GET is answered by the info
# page above, which returns 405 to an MCP client (see McpInfoController).
match '/mcp', to: 'mcp#unsupported_method', via: %i[delete put patch]

# Stateless OAuth 2.1 (authorization code + PKCE) protecting the MCP endpoint,
# plus the discovery documents. All gated on the same opt-in toggle as /mcp;
# when MCP is disabled they behave as 404. Clients discover the endpoints from
# the authorization-server metadata (which points them at /oauth/*).
get '/.well-known/oauth-protected-resource',
    to: 'oauth/metadata#protected_resource'
# RFC 9728 inserts the resource path after the well-known segment, so clients
# request the metadata for the /mcp resource here. Same document as above.
get '/.well-known/oauth-protected-resource/mcp',
    to: 'oauth/metadata#protected_resource'
get '/.well-known/oauth-authorization-server',
    to: 'oauth/metadata#authorization_server'
# We are an OAuth 2.1 server, not an OpenID Connect provider. Clients probe
# this path during discovery; answer with a clean 404 instead of letting it
# fall through to a logged RoutingError.
get '/.well-known/openid-configuration',
    to: 'oauth/metadata#openid_configuration'

scope :oauth, module: :oauth, as: :oauth do
  post 'register', to: 'registrations#create'
  get 'authorize', to: 'authorizations#new', as: :authorize
  post 'authorize', to: 'authorizations#create'
  post 'token', to: 'tokens#create'
end
