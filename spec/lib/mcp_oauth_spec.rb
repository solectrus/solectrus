describe McpOauth do
  let(:base_url) { 'https://pv.example.com' }

  describe '.signing_key' do
    it 'derives a stable key from secret_key_base (no separate secret)' do
      key = described_class.signing_key

      expect(key.bytesize).to eq(32)
      expect(described_class.signing_key).to eq(key)
    end

    # The admin password is the only credential this flow checks, so changing
    # it is an act of revocation. Before, it revoked nothing: every access and
    # refresh token minted under the old password kept working, for up to the
    # chain deadline, and only rotating the OAuth secret ended them.
    it 'ends every issued token when the admin password changes' do
      allow(Rails.configuration.x).to receive(:admin_password).and_return('old')
      token = described_class.encode_access_token(base_url:)
      expect(described_class.valid_access_token?(token, base_url:)).to be_present

      allow(Rails.configuration.x).to receive(:admin_password).and_return('new')

      expect(described_class.valid_access_token?(token, base_url:)).to be_nil
    end

    it 'keeps the key stable while the password does not change' do
      allow(Rails.configuration.x).to receive(:admin_password).and_return('same')
      key = described_class.signing_key

      expect(described_class.signing_key).to eq(key)
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
