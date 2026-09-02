describe McpOauth::Redirect do
  describe '.valid?' do
    it 'accepts any https callback (provider-agnostic, host shown for consent)' do
      expect(described_class.valid?('https://claude.ai/api/mcp/auth_callback')).to be(true)
      expect(described_class.valid?('https://chatgpt.com/connector/callback')).to be(true)
      expect(described_class.valid?('https://some-ai.example/cb')).to be(true)
    end

    it 'accepts loopback http callbacks on any port and path' do
      expect(described_class.valid?('http://localhost/callback')).to be(true)
      expect(described_class.valid?('http://localhost:51763/callback')).to be(true)
      expect(described_class.valid?('http://127.0.0.1:8080/callback')).to be(true)
      # mcp-remote uses /oauth/callback; the path is client-specific.
      expect(described_class.valid?('http://localhost:15597/oauth/callback')).to be(true)
    end

    it 'accepts the IPv6 loopback (brackets and all)' do
      expect(described_class.valid?('http://[::1]/callback')).to be(true)
      expect(described_class.valid?('http://[::1]:9999/callback')).to be(true)
    end

    # A browser-based client on the LAN (Open WebUI, LM Studio) rarely has TLS,
    # and reaches SOLECTRUS by address or by name.
    it 'accepts plain http on the admin network, by address or by name' do
      expect(described_class.valid?('http://192.168.1.98:8080/oauth/oidc/callback')).to be(true)
      expect(described_class.valid?('http://10.0.0.5/callback')).to be(true)
      expect(described_class.valid?('http://[fd00::1]:8080/cb')).to be(true)
      expect(described_class.valid?('http://openwebui:8080/cb')).to be(true)
      expect(described_class.valid?('http://openwebui.local/cb')).to be(true)
      expect(described_class.valid?('http://openwebui.fritz.box/cb')).to be(true)
    end

    # The consent page names the host, and the code is bound to a PKCE
    # challenge the client keeps. A scheme rule adds nothing on top: phishing
    # only ever needs an https host, which is accepted anyway.
    it 'accepts a public host over plain http as well' do
      expect(described_class.valid?('http://some-ai.example/cb')).to be(true)
      expect(described_class.valid?('http://8.8.8.8/cb')).to be(true)
    end

    it 'rejects non-http(s) schemes' do
      expect(described_class.valid?('ftp://example.com/cb')).to be(false)
    end

    it 'rejects a redirect without a path' do
      expect(described_class.valid?('https://example.com')).to be(false)
      expect(described_class.valid?('http://localhost:51763')).to be(false)
    end

    # These parse as a path alone. The consent page then names no
    # host, and a browser resolving the Location against a plain-http instance
    # reads the host back out of that path.
    it 'rejects a redirect without a host' do
      expect(described_class.valid?('https:/evil.com/callback')).to be(false)
      expect(described_class.valid?('https:///callback')).to be(false)
      expect(described_class.valid?('https://@/callback')).to be(false)
    end

    # An unusual host is not a suspicious one, and this is not a check of
    # hostname syntax.
    it 'accepts an unusual but resolvable host' do
      # Docker allows an underscore in a service name.
      expect(described_class.valid?('http://open_webui:8080/cb')).to be(true)
      # A fully qualified name may carry a trailing dot.
      expect(described_class.valid?('https://claude.ai./cb')).to be(true)
      # The scheme is case-insensitive.
      expect(described_class.valid?('HTTPS://Claude.AI/cb')).to be(true)
    end

    it 'rejects blank or malformed input' do
      expect(described_class.valid?(nil)).to be(false)
      expect(described_class.valid?('::::')).to be(false)
    end
  end

  # The consent page names this host, and that name is the whole guard: it has
  # to be what the browser resolves, not what the client wrote.
  describe '.host' do
    it 'names an ordinary host unchanged' do
      expect(described_class.host('https://claude.ai/cb')).to eq('claude.ai')
      expect(described_class.host('http://192.168.1.98:8080/cb')).to eq('192.168.1.98')
      expect(described_class.host('http://[fd00::1]:8080/cb')).to eq('[fd00::1]')
    end

    # RFC 3986 allows a percent escape in the authority, so this is a legal URL
    # that the stdlib keeps verbatim while the browser goes to "evil.com".
    it 'decodes an escape that hides the destination' do
      expect(described_class.host('http://%65vil.com/cb')).to eq('evil.com')
      expect(described_class.host('https://evil%2ecom/cb')).to eq('evil.com')
    end

    # As the address bar does, so a look-alike name cannot read as the real one.
    it 'punycodes a host spelled with a Cyrillic letter' do
      expect(described_class.host('http://pаypal.com/cb')).to start_with('xn--')
    end

    it 'names the host, not the userinfo in front of it' do
      expect(described_class.host('https://claude.ai@evil.com/cb')).to eq('evil.com')
    end

    it 'is nil for input that carries no host' do
      expect(described_class.host('https:/evil.com/cb')).to be_nil
      expect(described_class.host('::::')).to be_nil
    end
  end

  describe '.loopback?' do
    it 'is true for loopback http callbacks' do
      expect(described_class.loopback?('http://localhost:11158/oauth/callback')).to be(true)
      expect(described_class.loopback?('http://127.0.0.1/callback')).to be(true)
      expect(described_class.loopback?('http://[::1]:9999/callback')).to be(true)
    end

    it 'is false for remote https callbacks and malformed input' do
      expect(described_class.loopback?('https://claude.ai/api/mcp/auth_callback')).to be(false)
      expect(described_class.loopback?('https://localhost/callback')).to be(false)
      expect(described_class.loopback?('::::')).to be(false)
    end
  end
end
