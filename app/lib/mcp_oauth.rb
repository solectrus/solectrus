# Stateless OAuth 2.1 (authorization code + PKCE) protecting the MCP endpoint.
#
# SOLECTRUS is a single-user, self-hosted server with no user model, so this is
# deliberately minimal and fully stateless: every artifact (authorization code,
# access token, refresh token) is a signed JWT. Nothing is persisted, no
# Doorkeeper, no DB tables. The admin password is the only credential.
#
# The signing key is derived from the app's secret_key_base, so no extra secret
# is required. All tokens are HS256.
module McpOauth
  # Fixed public client. Dynamic Client Registration returns this id for every
  # request and stores nothing, so the user can add the connector by URL alone
  # (no client_id/secret to type into "Advanced settings").
  CLIENT_ID = 'solectrus-mcp-client'.freeze
  public_constant :CLIENT_ID

  ALGORITHM = 'HS256'.freeze
  private_constant :ALGORITHM

  ACCESS_TOKEN_TTL = 1.hour
  public_constant :ACCESS_TOKEN_TTL

  # Stateless refresh tokens cannot be rotated or individually revoked, so a
  # stolen one grants access until it expires. Kept short so a token that stops
  # being refreshed dies quickly; a connected client refreshes well within
  # this, so it is never user-visible.
  REFRESH_TOKEN_TTL = 14.days
  private_constant :REFRESH_TOKEN_TTL

  # How long ONE authorization may keep granting access, however often it is
  # refreshed.
  #
  # A refresh hands back a new refresh token, so the 14 days above bound only
  # an ABANDONED token. They bound nothing for a token in use: every refresh
  # started the fortnight over, and a stolen one renewed itself forever as long
  # as it was used at least once a fortnight. Only rotating the signing secret
  # ended that, and nothing told the admin to.
  #
  # The deadline is minted once, when the admin consents, and carried across
  # every refresh. So an authorization ends on a fixed date and the admin
  # re-consents about once a quarter.
  REFRESH_CHAIN_TTL = 90.days
  public_constant :REFRESH_CHAIN_TTL

  # Stateless authorization codes cannot be made strictly single-use. We
  # mitigate this with a very short lifetime plus binding to
  # redirect_uri/code_challenge. Acceptable for a single-user server.
  CODE_TTL = 60.seconds
  private_constant :CODE_TTL

  # Loopback hosts for native clients (Claude Desktop, Claude Code, and any
  # other AI client bridging via a local callback). Per RFC 8252 the port is
  # dynamic and MUST be ignored when matching; the path is client-specific
  # (mcp-remote uses /oauth/callback, others /callback) and is not pinned - a
  # loopback redirect can only be intercepted by a process on the local machine.
  LOOPBACK_HOSTS = %w[localhost 127.0.0.1 ::1].freeze
  private_constant :LOOPBACK_HOSTS

  class << self
    # MCP, OAuth and the discovery documents are all gated on the same opt-in
    # toggle and the sponsor policy. When unavailable every related route
    # behaves as 404.
    def available?
      Setting.mcp_enabled && ApplicationPolicy.mcp?
    end

    # Derived from secret_key_base, so no extra secret is required. Rails'
    # key_generator caches the derived key per salt, so this is cheap to call
    # per request.
    #
    # Two things are mixed into the salt, and each one ends every issued token
    # when it changes. The rotatable mcp_oauth_secret, which disabling MCP
    # rotates. And the admin password, because it is the only credential this
    # flow ever checks: an admin who changes it is revoking access, and without
    # this the tokens it granted outlived it by up to their chain deadline.
    def signing_key
      salt = [
        'solectrus-mcp-oauth',
        Setting.mcp_oauth_secret.presence,
        Rails.configuration.x.admin_password.presence,
      ].compact
      Rails.application.key_generator.generate_key(salt.join('-'), 32)
    end

    # Invalidate every issued token at once by rotating the signing salt. Used
    # when MCP is disabled, so all connected clients are dropped and must
    # re-authorize; re-enabling does not bring old connections back.
    def rotate_signing_secret!
      Setting.mcp_oauth_secret = SecureRandom.hex(32)
    end

    # --- Token minting ---

    def encode_code(base_url:, redirect_uri:, code_challenge:)
      encode(
        typ: 'code',
        iss: Urls.issuer(base_url),
        redirect_uri:,
        code_challenge:,
        exp: CODE_TTL.from_now.to_i,
      )
    end

    def encode_access_token(base_url:)
      encode(
        typ: 'access',
        iss: Urls.issuer(base_url),
        aud: Urls.resource_url(base_url),
        sub: 'admin',
        exp: ACCESS_TOKEN_TTL.from_now.to_i,
      )
    end

    # `chain_exp` is the deadline of the authorization this token continues -
    # nil starts a new chain, which is what an exchanged authorization code
    # does. A refresh token issued before the deadline existed carries none
    # either, so an upgrade starts its chain rather than dropping a client that
    # was connected all along.
    #
    # The deadline caps the token's own lifetime, so an exhausted chain needs
    # no check of its own: the token is expired, and JWT.decode refuses it like
    # any other expired token.
    def encode_refresh_token(base_url:, chain_exp: nil)
      deadline = chain_exp.presence || REFRESH_CHAIN_TTL.from_now.to_i

      encode(
        typ: 'refresh',
        iss: Urls.issuer(base_url),
        sub: 'admin',
        chain_exp: deadline,
        exp: [REFRESH_TOKEN_TTL.from_now.to_i, deadline].min,
      )
    end

    # Decode and verify signature + expiry. Raises JWT::DecodeError on any
    # failure (bad signature, expired, malformed). Callers check typ/aud/iss.
    def decode(token)
      payload, = JWT.decode(token, signing_key, true, algorithm: ALGORITHM)
      payload
    end

    # Validate a bearer token as an access token we issued for this resource.
    # Returns the payload on success, nil otherwise.
    def valid_access_token?(token, base_url:)
      payload = decode(token)
      payload if payload['typ'] == 'access' &&
        payload['aud'] == Urls.resource_url(base_url) &&
        payload['iss'] == Urls.issuer(base_url)
    rescue JWT::DecodeError
      nil
    end

    # --- PKCE (S256 only) ---

    def pkce_valid?(code_verifier, code_challenge)
      return false if code_verifier.blank? || code_challenge.blank?

      expected =
        Base64.urlsafe_encode64(
          OpenSSL::Digest::SHA256.digest(code_verifier.to_s),
          padding: false,
        )
      ActiveSupport::SecurityUtils.secure_compare(expected, code_challenge.to_s)
    end

    # --- Redirect URI validation ---

    # Provider-agnostic, so any AI client can connect: accept any HTTPS callback
    # (the target host is shown to the admin on the authorization page, so the
    # consent step - not a hardcoded allowlist - is what guards against a
    # phishing redirect to a foreign host) plus loopback HTTP for native
    # clients. Plain HTTP to non-loopback hosts is rejected (it would leak the
    # code in cleartext to a remote host).
    # A host is required, because the whole guard is that the admin sees one.
    # "https:/evil.com/cb" carries none: URI.parse reads it as path
    # "/evil.com/cb", so the consent page shows an empty host, and the browser
    # resolves the Location we send against the request URL - which invents the
    # host back out of the path whenever the two schemes differ, as they do on
    # a plain-http instance (docs/MCP.md offers one). The code then reaches a
    # host that was never named.
    def valid_redirect_uri?(redirect_uri)
      return false if redirect_uri.blank?

      uri = URI.parse(redirect_uri)
      uri.host.present? && uri.path.present? &&
        (uri.scheme == 'https' || loopback_redirect?(redirect_uri))
    rescue URI::InvalidURIError
      false
    end

    # A native client's loopback callback (http://localhost etc.)? Such a
    # redirect can only be received by a process on the admin's own machine, so
    # the consent page describes it as a local client instead of showing the
    # uninformative host "localhost".
    def loopback_redirect?(redirect_uri)
      uri = URI.parse(redirect_uri.to_s)
      # #hostname (not #host) strips IPv6 brackets: "[::1]" -> "::1".
      uri.scheme == 'http' && LOOPBACK_HOSTS.include?(uri.hostname)
    rescue URI::InvalidURIError
      false
    end

    # --- Credential check (reuses the existing admin password) ---

    def valid_admin_password?(password)
      AdminUser.password_correct?(password)
    end

    private

    def encode(payload)
      JWT.encode(
        payload.merge(iat: Time.current.to_i),
        signing_key,
        ALGORITHM,
      )
    end
  end
end
