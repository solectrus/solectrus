describe 'OAuth (MCP)' do
  # RFC 7636 appendix B sample pair.
  let(:code_verifier) { 'dBjftJeZ4CVP-mB92K27uhbUJU1p1r_wW1gFWFOEjXk' }
  let(:code_challenge) { 'E9Melhoa2OwvFrEMTJguCHaoeK1t8URWbuGJSstw-cM' }
  let(:redirect_uri) { 'http://localhost:9999/callback' }
  let(:admin_password) { 't0ps3cr3t' }

  def authorize_params(overrides = {})
    {
      response_type: 'code',
      client_id: McpOauth::CLIENT_ID,
      redirect_uri:,
      state: 'xyz',
      code_challenge:,
      code_challenge_method: 'S256',
    }.merge(overrides)
  end

  # Drive the whole authorization step and return the freshly minted code.
  def obtain_code
    post '/oauth/authorize', params: authorize_params(password: admin_password)
    expect(response).to have_http_status(:redirect)
    query = URI.parse(response.headers['Location']).query
    Rack::Utils.parse_query(query)['code']
  end

  context 'when MCP is disabled (default)' do
    it 'hides every OAuth and discovery endpoint (404)' do
      get '/.well-known/oauth-protected-resource'
      expect(response).to have_http_status(:not_found)

      get '/.well-known/oauth-protected-resource/mcp'
      expect(response).to have_http_status(:not_found)

      get '/.well-known/oauth-authorization-server'
      expect(response).to have_http_status(:not_found)

      post '/oauth/register'
      expect(response).to have_http_status(:not_found)

      get '/oauth/authorize', params: authorize_params
      expect(response).to have_http_status(:not_found)

      post '/oauth/token'
      expect(response).to have_http_status(:not_found)
    end
  end

  context 'when MCP is enabled' do
    before do
      Setting.mcp_enabled = true
      allow(ApplicationPolicy).to receive(:mcp?).and_return(true)
      allow(Rails.configuration.x).to receive(:admin_password).and_return(
        admin_password,
      )
    end

    describe 'CORS for browser-based AI clients' do
      it 'allows any origin on the discovery documents' do
        get '/.well-known/oauth-protected-resource',
            headers: {
              'Origin' => 'https://claude.ai',
            }

        expect(response.headers['Access-Control-Allow-Origin']).to eq('*')
      end
    end

    describe 'GET /.well-known/oauth-protected-resource' do
      it 'returns the resource metadata derived from the request host' do
        get '/.well-known/oauth-protected-resource'

        expect(response).to have_http_status(:success)
        expect(response.parsed_body).to eq(
          'resource' => 'http://www.example.com/mcp',
          'authorization_servers' => ['http://www.example.com'],
        )
      end

      it 'derives the host from the request, not a hardcoded value' do
        host! 'solar.example.org'
        get '/.well-known/oauth-protected-resource'

        expect(response.parsed_body['resource']).to eq(
          'http://solar.example.org/mcp',
        )
        expect(response.parsed_body['authorization_servers']).to eq(
          ['http://solar.example.org'],
        )
      end
    end

    describe 'GET /.well-known/oauth-protected-resource/mcp' do
      it 'serves the same metadata at the RFC 9728 path-aware location' do
        get '/.well-known/oauth-protected-resource/mcp'

        expect(response).to have_http_status(:success)
        expect(response.parsed_body).to eq(
          'resource' => 'http://www.example.com/mcp',
          'authorization_servers' => ['http://www.example.com'],
        )
      end
    end

    describe 'GET /.well-known/openid-configuration' do
      it 'returns a clean 404 (we are not an OIDC provider)' do
        get '/.well-known/openid-configuration'

        expect(response).to have_http_status(:not_found)
      end
    end

    describe 'GET /.well-known/oauth-authorization-server' do
      it 'advertises code + PKCE (S256) and a public client' do
        get '/.well-known/oauth-authorization-server'

        expect(response).to have_http_status(:success)
        body = response.parsed_body
        expect(body['issuer']).to eq('http://www.example.com')
        expect(body['authorization_endpoint']).to eq(
          'http://www.example.com/oauth/authorize',
        )
        expect(body['token_endpoint']).to eq(
          'http://www.example.com/oauth/token',
        )
        expect(body['registration_endpoint']).to eq(
          'http://www.example.com/oauth/register',
        )
        expect(body['response_types_supported']).to eq(['code'])
        expect(body['grant_types_supported']).to eq(
          %w[authorization_code refresh_token],
        )
        expect(body['code_challenge_methods_supported']).to eq(['S256'])
        expect(body['token_endpoint_auth_methods_supported']).to eq(['none'])
      end
    end

    describe 'POST /oauth/register' do
      it 'returns a usable fixed public client without storing anything' do
        post '/oauth/register',
             params: { redirect_uris: [redirect_uri] }.to_json,
             headers: {
               'CONTENT_TYPE' => 'application/json',
             }

        expect(response).to have_http_status(:created)
        body = response.parsed_body
        expect(body['client_id']).to eq(McpOauth::CLIENT_ID)
        expect(body['token_endpoint_auth_method']).to eq('none')
        expect(body['redirect_uris']).to eq([redirect_uri])
      end
    end

    describe 'GET /oauth/authorize' do
      it 'renders the password page for a valid request' do
        get '/oauth/authorize', params: authorize_params

        expect(response).to have_http_status(:success)
        expect(response.body).to include('type="password"')
      end

      it 'opens form-action to http(s) targets so the OAuth redirect works' do
        # Browsers enforce form-action against the post-submit redirect target,
        # so the app-wide `form-action 'self'` would block the OAuth redirect.
        # Server-side redirect_uri validation plus the consent step are the
        # real protection.
        get '/oauth/authorize', params: authorize_params

        csp = response.headers['Content-Security-Policy']
        expect(csp).to match(/form-action[^;]*\bhttp:/)
        expect(csp).to match(/form-action[^;]*\bhttps:/)
      end

      it 'shows the target host so the admin can vet where access goes' do
        get '/oauth/authorize',
            params: authorize_params(redirect_uri: 'https://some-ai.example/cb')

        expect(response.body).to include(I18n.t('oauth.authorize.client_host'))
        expect(response.body).to include('some-ai.example')
      end

      it 'describes a local client for a loopback callback (not "localhost")' do
        # Default redirect_uri is a loopback callback (native client).
        get '/oauth/authorize', params: authorize_params

        expect(response.body).to include(I18n.t('oauth.authorize.client_local'))
        expect(response.body).not_to include(I18n.t('oauth.authorize.client_host'))
      end

      it 'rejects a non-S256 challenge method' do
        get '/oauth/authorize',
            params: authorize_params(code_challenge_method: 'plain')

        expect(response).to have_http_status(:bad_request)
      end

      it 'rejects plain http to a non-loopback host' do
        get '/oauth/authorize',
            params: authorize_params(redirect_uri: 'http://evil.com/callback')

        expect(response).to have_http_status(:bad_request)
      end
    end

    describe 'POST /oauth/authorize' do
      it 'redirects back with a code and state for the correct password' do
        post '/oauth/authorize',
             params: authorize_params(password: admin_password)

        expect(response).to have_http_status(:redirect)
        location = URI.parse(response.headers['Location'])
        query = Rack::Utils.parse_query(location.query)
        expect(location.host).to eq('localhost')
        expect(query['code']).to be_present
        expect(query['state']).to eq('xyz')
      end

      it 're-renders with a generic error for a wrong password' do
        post '/oauth/authorize',
             params: authorize_params(password: 'wrong')

        expect(response).to have_http_status(:unauthorized)
        expect(response.body).to include(I18n.t('oauth.authorize.error'))
        # No info leak / no code issued.
        expect(response.body).not_to include('code=')
      end

      # The admin password is the only credential guarding MCP access, and this
      # is the one endpoint that checks it without a session - reachable from
      # the internet on any instance following docs/MCP.md. Unthrottled it
      # answered guesses as fast as they arrived.
      describe 'guessing the password' do
        def guess(times)
          times.times do
            post '/oauth/authorize', params: authorize_params(password: 'wrong')
          end
        end

        it 'stops answering after ten attempts from one address' do
          guess(10)
          expect(response).to have_http_status(:unauthorized)

          guess(1)
          expect(response).to have_http_status(:too_many_requests)
          expect(response.body).to include(I18n.t('oauth.authorize.throttled_title'))
        end

        # A throttled attempt must not be handed back to the client's callback:
        # that would return the attempt to whoever is making it.
        it 'renders rather than redirecting' do
          guess(11)

          expect(response.headers['Location']).to be_nil
        end

        # The limit guards the credential check, so the correct password is
        # refused too - otherwise an attacker learns when they have found it.
        it 'refuses the right password too, once the limit is reached' do
          guess(11)

          post '/oauth/authorize', params: authorize_params(password: admin_password)

          expect(response).to have_http_status(:too_many_requests)
        end
      end

      it 'does not redirect to a disallowed redirect_uri even with the password' do
        post '/oauth/authorize',
             params:
               authorize_params(
                 redirect_uri: 'http://evil.com/callback',
                 password: admin_password,
               )

        expect(response).to have_http_status(:bad_request)
      end
    end

    describe 'POST /oauth/token (authorization_code)' do
      it 'exchanges a valid code + PKCE verifier for tokens' do
        code = obtain_code

        post '/oauth/token',
             params: {
               grant_type: 'authorization_code',
               code:,
               code_verifier:,
               redirect_uri:,
               client_id: McpOauth::CLIENT_ID,
             }

        expect(response).to have_http_status(:success)
        body = response.parsed_body
        expect(body['token_type']).to eq('Bearer')
        expect(body['access_token']).to be_present
        expect(body['refresh_token']).to be_present
        expect(
          McpOauth.valid_access_token?(
            body['access_token'],
            base_url: 'http://www.example.com',
          ),
        ).to be_present
      end

      it 'rejects a mismatched PKCE verifier with invalid_grant' do
        code = obtain_code

        post '/oauth/token',
             params: {
               grant_type: 'authorization_code',
               code:,
               code_verifier: 'wrong-verifier',
               redirect_uri:,
               client_id: McpOauth::CLIENT_ID,
             }

        expect(response).to have_http_status(:bad_request)
        expect(response.parsed_body['error']).to eq('invalid_grant')
      end

      it 'rejects a tampered redirect_uri with invalid_grant' do
        code = obtain_code

        post '/oauth/token',
             params: {
               grant_type: 'authorization_code',
               code:,
               code_verifier:,
               redirect_uri: 'http://localhost:1/callback',
               client_id: McpOauth::CLIENT_ID,
             }

        expect(response).to have_http_status(:bad_request)
        expect(response.parsed_body['error']).to eq('invalid_grant')
      end

      it 'rejects a garbage code with invalid_grant' do
        post '/oauth/token',
             params: {
               grant_type: 'authorization_code',
               code: 'not-a-jwt',
               code_verifier:,
               redirect_uri:,
             }

        expect(response).to have_http_status(:bad_request)
        expect(response.parsed_body['error']).to eq('invalid_grant')
      end
    end

    describe 'POST /oauth/token (refresh_token)' do
      it 'issues a fresh access token for a valid refresh token' do
        code = obtain_code
        post '/oauth/token',
             params: {
               grant_type: 'authorization_code',
               code:,
               code_verifier:,
               redirect_uri:,
               client_id: McpOauth::CLIENT_ID,
             }
        refresh_token = response.parsed_body['refresh_token']

        post '/oauth/token',
             params: {
               grant_type: 'refresh_token',
               refresh_token:,
             }

        expect(response).to have_http_status(:success)
        expect(
          McpOauth.valid_access_token?(
            response.parsed_body['access_token'],
            base_url: 'http://www.example.com',
          ),
        ).to be_present
      end

      it 'rejects an access token used as a refresh token' do
        access = McpOauth.encode_access_token(base_url: 'http://www.example.com')

        post '/oauth/token',
             params: { grant_type: 'refresh_token', refresh_token: access }

        expect(response).to have_http_status(:bad_request)
        expect(response.parsed_body['error']).to eq('invalid_grant')
      end

      it 'rejects a refresh token issued for a different host (wrong iss)' do
        other = McpOauth.encode_refresh_token(base_url: 'http://evil.example')

        post '/oauth/token',
             params: { grant_type: 'refresh_token', refresh_token: other }

        expect(response).to have_http_status(:bad_request)
        expect(response.parsed_body['error']).to eq('invalid_grant')
      end

      # A refresh hands back a new refresh token, so the fortnight it is valid
      # for bounds only an abandoned token. Without a deadline that outlives
      # the rotation, a token in use renewed itself forever - and a stolen one
      # with it.
      describe 'the chain of refreshes' do
        def refresh_once(token)
          post '/oauth/token',
               params: { grant_type: 'refresh_token', refresh_token: token }
          response.parsed_body['refresh_token']
        end

        it 'keeps the deadline the authorization was granted with' do
          first = McpOauth.encode_refresh_token(base_url: 'http://www.example.com')
          deadline = McpOauth.decode(first)['chain_exp']

          second = refresh_once(first)

          expect(McpOauth.decode(second)['chain_exp']).to eq(deadline)
        end

        it 'refuses to reach past it, however often it is refreshed' do
          token = McpOauth.encode_refresh_token(base_url: 'http://www.example.com')
          deadline = McpOauth.decode(token)['chain_exp']

          # A client renewing every fortnight, well past the 90 days.
          6.times do
            travel 13.days
            token = refresh_once(token)
            expect(token).to be_present
          end
          travel 13.days

          expect(refresh_once(token)).to be_nil
          expect(response.parsed_body['error']).to eq('invalid_grant')
          expect(deadline).to be < Time.current.to_i
        end

        # A token minted before the deadline existed carries none. Dropping
        # those would disconnect every client on an upgrade, for a theft
        # nobody reported.
        it 'starts a chain for a token issued before there were any' do
          legacy =
            JWT.encode(
              {
                typ: 'refresh',
                iss: 'http://www.example.com',
                sub: 'admin',
                exp: 3.days.from_now.to_i,
              },
              McpOauth.signing_key,
              'HS256',
            )

          expect(McpOauth.decode(refresh_once(legacy))['chain_exp']).to be_present
        end
      end
    end

    describe 'POST /oauth/token (unknown grant)' do
      it 'returns unsupported_grant_type' do
        post '/oauth/token', params: { grant_type: 'password' }

        expect(response).to have_http_status(:bad_request)
        expect(response.parsed_body['error']).to eq('unsupported_grant_type')
      end
    end
  end
end
