describe Version do
  describe '.latest' do
    subject(:latest) { described_class.latest }

    before { Rails.application.load_seed }

    context 'when the request succeeds', vcr: { cassette_name: 'version' } do
      it { is_expected.to eq('v0.10.1') }
    end

    context 'when the request fails' do
      before do
        stub_request(:get, Version::CHECK_URL).to_return(
          status: [500, 'Internal Server Error'],
        )
      end

      it { is_expected.to be_nil }
    end

    context 'when the request timeouts' do
      before { stub_request(:get, Version::CHECK_URL).to_timeout }

      it { is_expected.to be_nil }
    end

    context 'when response is invalid', vcr: { cassette_name: 'version' } do
      before { allow(JSON).to receive(:parse).and_raise(JSON::ParserError) }

      it { is_expected.to be_nil }
    end
  end

  describe 'caching' do
    include_context 'with cache'

    it 'caches the version' do
      # The first request will be cached
      VCR.use_cassette('version') do
        expect(described_class.latest).to eq('v0.10.1')
      end

      # The second request is cached, so the cassette is not used
      expect(described_class.new.cached?).to be true
      expect(described_class.latest).to eq('v0.10.1')

      # The cache expires after some time
      travel 2.days do
        expect(described_class.new.cached?).to be false
      end
    end

    it 'can be reset' do
      # Fill the cache
      VCR.use_cassette('version') { described_class.latest }

      expect { described_class.clear_cache }.to change {
        described_class.new.cached?
      }.from(true).to(false)
    end
  end
end
