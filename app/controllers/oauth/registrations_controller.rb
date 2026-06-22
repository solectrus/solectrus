# Dynamic Client Registration (RFC 7591), stateless.
#
# We accept Claude's client metadata, store nothing, and always return the same
# fixed public client_id with auth method "none" (public client + PKCE). This
# lets the user add the connector by URL alone, with no client_id/secret to
# enter in "Advanced settings".
class Oauth::RegistrationsController < Oauth::BaseController
  def create
    render json: {
             client_id: McpOauth::CLIENT_ID,
             token_endpoint_auth_method: 'none',
             grant_types: %w[authorization_code refresh_token],
             response_types: %w[code],
             redirect_uris: Array(params[:redirect_uris]),
           },
           status: :created
  end
end
