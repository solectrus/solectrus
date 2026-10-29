describe HeliosCheck do
  subject(:instance) { described_class.instance }

  before do
    # Allow probing in these tests (normally skipped in local environments)
    allow(described_class).to receive(:skip_http?).and_return(false)
    # Use a real (memory) cache so caching behavior can be verified
    allow(Rails).to receive(:cache).and_return(
      ActiveSupport::Cache::MemoryStore.new,
    )
    instance.clear_cache!
  end

  describe '#version' do
    subject(:version) { instance.version }

    context 'when helios responds with X-Version header' do
      before do
        stub_request(:get, 'http://helios:3000/up').to_return(
          status: 200,
          headers: {
            'X-Version' => '2.5.1',
          },
        )
      end

      it { is_expected.to eq('2.5.1') }

      it 'caches the result' do
        version
        expect(Rails.cache.read('HeliosCheck:version')).to eq('2.5.1')
      end
    end

    context 'when helios responds without X-Version header' do
      before { stub_request(:get, 'http://helios:3000/up').to_return(status: 200) }

      it { is_expected.to be_nil }
    end

    context 'when helios returns a non-success status' do
      before { stub_request(:get, 'http://helios:3000/up').to_return(status: 503) }

      it { is_expected.to be_nil }
    end

    context 'when hostname does not resolve' do
      before do
        stub_request(:get, 'http://helios:3000/up').to_raise(
          SocketError.new('getaddrinfo: Name does not resolve'),
        )
      end

      it { is_expected.to be_nil }
    end

    context 'when probe times out' do
      before { stub_request(:get, 'http://helios:3000/up').to_timeout }

      it { is_expected.to be_nil }
    end

    context 'when running in test/development' do
      before { allow(described_class).to receive(:skip_http?).and_return(true) }

      it { is_expected.to be_nil }
    end
  end

  # The cache can hold the version from before an update of HELIOS.
  describe '#version, not cached' do
    subject(:uncached_version) { instance.version(cached: false) }

    before do
      Rails.cache.write('HeliosCheck:version', '2.5.0')
      stub_request(:get, 'http://helios:3000/up').to_return(
        status: 200,
        headers: {
          'X-Version' => '2.5.1',
        },
      )
    end

    it { is_expected.to eq('2.5.1') }

    it 'renews the cache' do
      uncached_version
      expect(instance.version).to eq('2.5.1')
    end

    context 'when helios is unreachable' do
      before { stub_request(:get, 'http://helios:3000/up').to_timeout }

      it 'forgets the version' do
        expect(uncached_version).to be_nil
        expect(instance).not_to be_available
      end
    end

    context 'when running in test/development' do
      before { allow(described_class).to receive(:skip_http?).and_return(true) }

      it { is_expected.to be_nil }
    end
  end

  describe '#action_required?' do
    subject(:action_required) { instance.action_required? }

    context 'when helios sets X-Action-Required' do
      before do
        stub_request(:get, 'http://helios:3000/up').to_return(
          status: 200,
          headers: {
            'X-Version' => '2.5.1',
            'X-Action-Required' => '1',
          },
        )
      end

      it { is_expected.to be true }

      # The user fixes the request in HELIOS, so the dot must leave soon.
      it 'asks again after 30 seconds' do
        action_required
        travel(29.seconds) { instance.action_required? }
        expect(a_request(:get, 'http://helios:3000/up')).to have_been_made.twice

        travel(31.seconds) { instance.action_required? }
        expect(a_request(:get, 'http://helios:3000/up')).to have_been_made.times(3)
      end
    end

    # Also an older HELIOS, which does not know the header.
    context 'when helios leaves X-Action-Required out' do
      before do
        stub_request(:get, 'http://helios:3000/up').to_return(
          status: 200,
          headers: {
            'X-Version' => '2.5.1',
          },
        )
      end

      it { is_expected.to be false }

      # A new request of HELIOS can reach the user late.
      it 'asks again after an hour' do
        action_required
        travel(59.minutes) { instance.action_required? }
        expect(a_request(:get, 'http://helios:3000/up')).to have_been_made.twice

        travel(61.minutes) { instance.action_required? }
        expect(a_request(:get, 'http://helios:3000/up')).to have_been_made.times(3)
      end
    end

    context 'when helios is unreachable' do
      before { stub_request(:get, 'http://helios:3000/up').to_timeout }

      it { is_expected.to be false }
    end

    context 'when running in test/development' do
      before { allow(described_class).to receive(:skip_http?).and_return(true) }

      it { is_expected.to be false }
    end
  end

  describe '#available?' do
    subject(:available) { instance.available? }

    context 'when helios responds with a version' do
      before do
        stub_request(:get, 'http://helios:3000/up').to_return(
          status: 200,
          headers: {
            'X-Version' => '2.5.1',
          },
        )
      end

      it { is_expected.to be true }
    end

    context 'when helios is unreachable' do
      before { stub_request(:get, 'http://helios:3000/up').to_timeout }

      it { is_expected.to be false }
    end
  end

  # Behind a reverse proxy the host of the request names the domain, while
  # HELIOS reports the URL it was opened at
  describe '#browser_url' do
    subject(:browser_url) { instance.browser_url(request) }

    let(:request) do
      instance_double(ActionDispatch::Request, protocol: 'https://', host: 'solectrus.example.com')
    end

    def helios_answers(headers)
      stub_request(:get, 'http://helios:3000/up').to_return(status: 200, headers:)
    end

    it 'takes the URL that HELIOS reports' do
      helios_answers('X-Browser-Url' => 'http://192.168.1.10:3999')

      expect(browser_url).to eq('http://192.168.1.10:3999')
    end

    it 'takes the host of the request when HELIOS reports no URL' do
      helios_answers('X-Version' => '2.5.1')

      expect(browser_url).to eq('https://solectrus.example.com:3999')
    end

    it 'takes the host of the request when HELIOS does not answer' do
      stub_request(:get, 'http://helios:3000/up').to_timeout

      expect(browser_url).to eq('https://solectrus.example.com:3999')
    end

    it 'ignores a URL that is no web address' do
      helios_answers('X-Browser-Url' => 'ftp://192.168.1.10')

      expect(browser_url).to eq('https://solectrus.example.com:3999')
    end

    context 'when running in test/development' do
      before { allow(described_class).to receive(:skip_http?).and_return(true) }

      it 'takes the host of the request' do
        expect(browser_url).to eq('https://solectrus.example.com:3999')
      end
    end
  end
end
