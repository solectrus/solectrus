module McpOauth
  # Who this deployment says it is, as an OAuth server: the issuer, the
  # protected resource, and the endpoints the discovery documents advertise.
  #
  # All of it is derived from the base URL of the request being answered, never
  # from a configured host. So the values a client discovers are the ones it is
  # later checked against, and an instance reachable under two names works
  # under both without either being declared.
  #
  # Split from McpOauth because this is the one part that touches no secret and
  # decides nothing: pure string derivation, called from the controllers as
  # much as from the token minting.
  module Urls
    module_function

    def issuer(base_url) = base_url
    def resource_url(base_url) = "#{base_url}/mcp"
    def authorization_endpoint(base_url) = "#{base_url}/oauth/authorize"
    def token_endpoint(base_url) = "#{base_url}/oauth/token"
    def registration_endpoint(base_url) = "#{base_url}/oauth/register"

    def protected_resource_metadata_url(base_url) = "#{base_url}/.well-known/oauth-protected-resource"

    # Append the authorization code (and optional state) to the client's
    # redirect_uri, preserving any query the client already put there.
    #
    # Only the host is normalized, and for two reasons. A Location header must
    # be ASCII, which a host spelled in another script is not. And the consent
    # page named the normalized host, so normalizing here is what makes the
    # page's promise true - the code goes to the host the admin read.
    #
    # The rest is left exactly as the client wrote it. Normalizing the whole
    # URL would rewrite escapes in the query ("%3D" back to "="), which
    # changes the state the client gets back.
    def callback(redirect_uri, code:, state: nil)
      uri = Addressable::URI.parse(redirect_uri)
      query = URI.decode_www_form(uri.query || '')
      query << ['code', code]
      query << ['state', state] if state.present?
      uri.query = URI.encode_www_form(query)
      uri.host = uri.normalized_host
      uri.to_s
    end
  end
end
