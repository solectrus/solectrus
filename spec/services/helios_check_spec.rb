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
end
