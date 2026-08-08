# OAuth token endpoint (RFC 6749). Public client, so no client authentication;
# PKCE protects the authorization_code grant.
class Oauth::TokensController < Oauth::BaseController
  def create
    case params[:grant_type]
    when 'authorization_code' then exchange_code
    when 'refresh_token' then refresh
    else render_error('unsupported_grant_type')
    end
  end

  private

  def exchange_code
    payload = decode_grant(:code)

    return render_error('invalid_grant') unless payload && valid_code?(payload)

    issue_tokens
  end

  def refresh
    payload = decode_grant(:refresh_token)

    unless payload && payload['typ'] == 'refresh' && issued_here?(payload)
      return render_error('invalid_grant')
    end

    issue_tokens
  end

  # Decode a grant JWT (auth code or refresh token), returning the payload or
  # nil for a bad/expired/malformed token.
  def decode_grant(param)
    McpOauth.decode(params[param].to_s)
  rescue JWT::DecodeError
    nil
  end

  def valid_code?(payload)
    payload['typ'] == 'code' &&
      issued_here?(payload) &&
      payload['redirect_uri'] == params[:redirect_uri] &&
      McpOauth.pkce_valid?(params[:code_verifier], payload['code_challenge'])
  end

  # The grant must have been issued by this very host. The signing key is
  # shared across hostnames (derived from secret_key_base), so the iss claim is
  # what binds a code/refresh token to the host it was minted for.
  def issued_here?(payload)
    payload['iss'] == McpOauth::Urls.issuer(oauth_base_url)
  end

  def issue_tokens
    base = oauth_base_url

    render json: {
      access_token: McpOauth.encode_access_token(base_url: base),
      token_type: 'Bearer',
      expires_in: McpOauth::ACCESS_TOKEN_TTL.to_i,
      refresh_token: McpOauth.encode_refresh_token(base_url: base),
    }
  end

  def render_error(code, status: :bad_request)
    render json: { error: code }, status:
  end
end
