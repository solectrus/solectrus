describe UpdateCheck do
  subject(:instance) { described_class.instance }

  before { Rails.application.load_seed }

  describe '.latest' do
    subject(:latest) { instance.latest }

    context 'when the request succeeds', vcr: { cassette_name: 'version' } do
      it do
        is_expected.to eq(
          { 'version' => 'v0.12.0', 'registration_status' => 'unregistered' },
        )
      end

      it 'has shortcuts' do
        expect(instance.latest_version).to eq('v0.12.0')
        expect(instance.registration_status).to be_unregistered
      end
    end

    context 'when the request fails' do
      before do
        stub_request(:get, UpdateCheck::URL).to_return(
          status: [500, 'Internal Server Error'],
        )
      end

      it { is_expected.to be_blank }

      it 'has blank shortcuts' do
        expect(instance.latest_version).to be_blank
        expect(instance.registration_status).to be_blank
      end
    end

    context 'when the request timeouts' do
      before { stub_request(:get, UpdateCheck::URL).to_timeout }

      it { is_expected.to be_blank }

      it 'has blank shortcuts' do
        expect(instance.latest_version).to be_blank
        expect(instance.registration_status).to be_blank
      end
    end

    context 'when response is invalid', vcr: { cassette_name: 'version' } do
      before { allow(JSON).to receive(:parse).and_raise(JSON::ParserError) }

      it { is_expected.to be_blank }

      it 'has blank shortcuts' do
        expect(instance.latest_version).to be_blank
        expect(instance.registration_status).to be_blank
      end
    end
  end

  describe '.skip_registration' do
    include_context 'with cache'

    it 'sets status' do
      expect { instance.skip_registration }.to change(
        instance,
        :registration_status,
      ).to('skipped')
    end
  end

  describe 'caching' do
    include_context 'with cache'

    it 'caches the version' do
      # The first request will be cached
      VCR.use_cassette('version') { expect(instance.latest).to be_present }

      # The second request is cached, so the cassette is not used
      expect(instance.cached?).to be true
      expect(instance.latest).to be_present

      # The cache expires after some time
      travel 2.days do
        expect(instance.cached?).to be false
      end
    end

    it 'can be reset' do
      # Fill the cache
      VCR.use_cassette('version') { instance.latest }

      expect { instance.clear_cache }.to change(instance, :cached?).from(
        true,
      ).to(false)
    end
  end
end
