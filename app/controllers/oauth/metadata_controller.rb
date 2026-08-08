# OAuth discovery documents.
class Oauth::MetadataController < Oauth::BaseController
  # RFC 9728 - Protected Resource Metadata
  def protected_resource
    render json: {
      resource: McpOauth::Urls.resource_url(oauth_base_url),
      authorization_servers: [McpOauth::Urls.issuer(oauth_base_url)],
    }
  end

  # OpenID Connect discovery is not offered (we are an OAuth 2.1 server, not an
  # OIDC provider). Clients probe this path anyway; answer with a clean 404 so
  # it does not surface as a logged routing exception.
  def openid_configuration
    head :not_found
  end

  # RFC 8414 - Authorization Server Metadata
  def authorization_server
    base = oauth_base_url

    render json: {
      issuer: McpOauth::Urls.issuer(base),
      authorization_endpoint: McpOauth::Urls.authorization_endpoint(base),
      token_endpoint: McpOauth::Urls.token_endpoint(base),
      registration_endpoint: McpOauth::Urls.registration_endpoint(base),
      response_types_supported: %w[code],
      grant_types_supported: %w[authorization_code refresh_token],
      code_challenge_methods_supported: %w[S256],
      # Public client + PKCE, no client secret.
      token_endpoint_auth_methods_supported: %w[none],
    }
  end
end
