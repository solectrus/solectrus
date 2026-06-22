# OAuth discovery documents.
class Oauth::MetadataController < Oauth::BaseController
  # RFC 9728 - Protected Resource Metadata
  def protected_resource
    render json: {
      resource: McpOauth.resource_url(oauth_base_url),
      authorization_servers: [McpOauth.issuer(oauth_base_url)],
    }
  end

  # RFC 8414 - Authorization Server Metadata
  def authorization_server
    base = oauth_base_url

    render json: {
      issuer: McpOauth.issuer(base),
      authorization_endpoint: McpOauth.authorization_endpoint(base),
      token_endpoint: McpOauth.token_endpoint(base),
      registration_endpoint: McpOauth.registration_endpoint(base),
      response_types_supported: %w[code],
      grant_types_supported: %w[authorization_code refresh_token],
      code_challenge_methods_supported: %w[S256],
      # Public client + PKCE, no client secret.
      token_endpoint_auth_methods_supported: %w[none],
    }
  end
end
