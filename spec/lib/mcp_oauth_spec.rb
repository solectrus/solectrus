describe McpOauth do
  let(:base_url) { 'https://pv.example.com' }

  describe '.signing_key' do
    it 'derives a stable key from secret_key_base (no separate secret)' do
      key = described_class.signing_key

      expect(key.bytesize).to eq(32)
      # Deterministic while the rotatable secret is blank: the base salt only.
      expect(Rails.application.key_generator.generate_key('solectrus-mcp-oauth', 32)).to eq(key)
    end
  end

  describe '.rotate_signing_secret!' do
    it 'changes the signing key' do
      before = described_class.signing_key
      described_class.rotate_signing_secret!

      expect(described_class.signing_key).not_to eq(before)
    end

    it 'invalidates tokens issued before the rotation' do
      token = described_class.encode_access_token(base_url:)
      expect(described_class.valid_access_token?(token, base_url:)).to be_present

      described_class.rotate_signing_secret!

      expect(described_class.valid_access_token?(token, base_url:)).to be_nil
    end
  end

  describe '.encode_access_token / .valid_access_token?' do
    it 'accepts a token issued for the same resource' do
      token = described_class.encode_access_token(base_url:)

      payload = described_class.valid_access_token?(token, base_url:)
      expect(payload).to include('typ' => 'access', 'aud' => "#{base_url}/mcp")
    end

    it 'rejects a token issued for a different resource (wrong aud)' do
      token = described_class.encode_access_token(base_url:)

      expect(
        described_class.valid_access_token?(token, base_url: 'https://evil.example'),
      ).to be_nil
    end

    it 'rejects an expired token' do
      token = described_class.encode_access_token(base_url:)

      travel(1.minute + described_class::ACCESS_TOKEN_TTL) do
        expect(described_class.valid_access_token?(token, base_url:)).to be_nil
      end
    end

    it 'rejects a refresh token used as an access token (wrong typ)' do
      token = described_class.encode_refresh_token(base_url:)

      expect(described_class.valid_access_token?(token, base_url:)).to be_nil
    end

    it 'rejects a garbage token' do
      expect(described_class.valid_access_token?('nonsense', base_url:)).to be_nil
    end
  end

  describe '.pkce_valid?' do
    # Known S256 pair from RFC 7636 appendix B.
    let(:verifier) { 'dBjftJeZ4CVP-mB92K27uhbUJU1p1r_wW1gFWFOEjXk' }
    let(:challenge) { 'E9Melhoa2OwvFrEMTJguCHaoeK1t8URWbuGJSstw-cM' }

    it 'accepts a matching S256 verifier/challenge' do
      expect(described_class.pkce_valid?(verifier, challenge)).to be(true)
    end

    it 'rejects a mismatched verifier' do
      expect(described_class.pkce_valid?('wrong', challenge)).to be(false)
    end

    it 'rejects blank input' do
      expect(described_class.pkce_valid?('', challenge)).to be(false)
      expect(described_class.pkce_valid?(verifier, '')).to be(false)
    end
  end

  describe '.valid_redirect_uri?' do
    it 'accepts any https callback (provider-agnostic, host shown for consent)' do
      expect(described_class.valid_redirect_uri?('https://claude.ai/api/mcp/auth_callback')).to be(true)
      expect(described_class.valid_redirect_uri?('https://chatgpt.com/connector/callback')).to be(true)
      expect(described_class.valid_redirect_uri?('https://some-ai.example/cb')).to be(true)
    end

    it 'accepts loopback http callbacks on any port and path' do
      expect(described_class.valid_redirect_uri?('http://localhost/callback')).to be(true)
      expect(described_class.valid_redirect_uri?('http://localhost:51763/callback')).to be(true)
      expect(described_class.valid_redirect_uri?('http://127.0.0.1:8080/callback')).to be(true)
      # mcp-remote uses /oauth/callback; the path is client-specific.
      expect(described_class.valid_redirect_uri?('http://localhost:15597/oauth/callback')).to be(true)
    end

    it 'accepts the IPv6 loopback (brackets stripped via #hostname)' do
      expect(described_class.valid_redirect_uri?('http://[::1]/callback')).to be(true)
      expect(described_class.valid_redirect_uri?('http://[::1]:9999/callback')).to be(true)
    end

    it 'rejects plain http to non-loopback hosts (would leak the code)' do
      expect(described_class.valid_redirect_uri?('http://evil.com/callback')).to be(false)
      expect(described_class.valid_redirect_uri?('http://example.com/cb')).to be(false)
    end

    it 'rejects non-http(s) schemes' do
      expect(described_class.valid_redirect_uri?('ftp://example.com/cb')).to be(false)
    end

    it 'rejects a redirect without a path' do
      expect(described_class.valid_redirect_uri?('https://example.com')).to be(false)
      expect(described_class.valid_redirect_uri?('http://localhost:51763')).to be(false)
    end

    it 'rejects blank or malformed input' do
      expect(described_class.valid_redirect_uri?(nil)).to be(false)
      expect(described_class.valid_redirect_uri?('::::')).to be(false)
    end
  end

  describe '.loopback_redirect?' do
    it 'is true for loopback http callbacks' do
      expect(described_class.loopback_redirect?('http://localhost:11158/oauth/callback')).to be(true)
      expect(described_class.loopback_redirect?('http://127.0.0.1/callback')).to be(true)
      expect(described_class.loopback_redirect?('http://[::1]:9999/callback')).to be(true)
    end

    it 'is false for remote https callbacks and malformed input' do
      expect(described_class.loopback_redirect?('https://claude.ai/api/mcp/auth_callback')).to be(false)
      expect(described_class.loopback_redirect?('https://localhost/callback')).to be(false)
      expect(described_class.loopback_redirect?('::::')).to be(false)
    end
  end

  describe '.valid_admin_password?' do
    before do
      allow(Rails.configuration.x).to receive(:admin_password).and_return('s3cret')
    end

    it 'accepts the configured admin password' do
      expect(described_class.valid_admin_password?('s3cret')).to be(true)
    end

    it 'rejects a wrong password' do
      expect(described_class.valid_admin_password?('nope')).to be(false)
    end

    it 'rejects when no password is configured' do
      allow(Rails.configuration.x).to receive(:admin_password).and_return(nil)
      expect(described_class.valid_admin_password?('anything')).to be(false)
    end
  end
end
