describe UpdateCheck do
  subject(:instance) { described_class.instance }

  before { Rails.application.load_seed }

  describe '.latest' do
    subject(:latest) { instance.latest }

    context 'when the request succeeds', vcr: { cassette_name: 'version' } do
      it do
        is_expected.to eq(
          { version: 'v0.14.5', registration_status: 'unregistered' },
        )
      end

      it 'has shortcuts' do
        expect(instance.latest_version).to eq('v0.14.5')
        expect(instance.registration_status).to be_unregistered
      end
    end

    context 'when the request fails' do
      before do
        stub_request(:get, 'https://update.solectrus.de').to_return(
          status: [500, 'Something went wrong'],
        )
        allow(Rails.logger).to receive(:error)
      end

      it do
        is_expected.to eq(registration_status: 'unknown', version: 'unknown')
      end

      it 'has unknown shortcuts' do
        expect(instance.latest_version).to eq('unknown')
        expect(instance.registration_status).to be_unknown
      end

      it 'logs the error' do
        latest

        expect(Rails.logger).to have_received(:error).with(
          'UpdateCheck failed: Error 500 - Something went wrong',
        ).once
      end
    end

    context 'when the request timeouts' do
      before do
        stub_request(:get, 'https://update.solectrus.de').to_timeout
        allow(Rails.logger).to receive(:error)
      end

      it do
        is_expected.to eq(registration_status: 'unknown', version: 'unknown')
      end

      it 'has blank shortcuts' do
        expect(instance.latest_version).to eq('unknown')
        expect(instance.registration_status).to be_unknown
      end

      it 'logs the error' do
        latest

        expect(Rails.logger).to have_received(:error).with(
          'UpdateCheck failed with timeout: execution expired',
        ).once
      end
    end

    context 'when the request fails with SSL error' do
      before do
        stub_request(:get, 'https://update.solectrus.de').to_raise(
          OpenSSL::SSL::SSLError,
        )
        allow(Rails.logger).to receive(:error)
      end

      it do
        is_expected.to eq(registration_status: 'unknown', version: 'unknown')
      end

      it 'has blank shortcuts' do
        expect(instance.latest_version).to eq('unknown')
        expect(instance.registration_status).to be_unknown
      end

      it 'logs the error' do
        latest

        expect(Rails.logger).to have_received(:error).with(
          'UpdateCheck failed with SSL error: Exception from WebMock',
        ).once
      end
    end

    context 'when response is invalid', vcr: { cassette_name: 'version' } do
      before do
        allow(JSON).to receive(:parse).and_raise(JSON::ParserError)
        allow(Rails.logger).to receive(:error)
      end

      it do
        is_expected.to eq(registration_status: 'unknown', version: 'unknown')
      end

      it 'has blank shortcuts' do
        expect(instance.latest_version).to eq('unknown')
        expect(instance.registration_status).to be_unknown
      end

      it 'logs the error' do
        latest

        expect(Rails.logger).to have_received(:error).with(
          'UpdateCheck failed: JSON::ParserError',
        ).once
      end
    end
  end

  describe '#prompt?' do
    subject { instance.prompt? }

    context 'when not registered' do
      it { is_expected.to be false }
    end
  end

  describe '.skip_prompt!' do
    include_context 'with cache'

    it 'sets status for some time' do
      expect { instance.skip_prompt! }.to change(
        instance,
        :skipped_prompt?,
      ).from(false).to(true)

      # The cache expires after some time
      travel 24.hours + 1 do
        expect(instance.skipped_prompt?).to be false
      end
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
      travel 12.hours + 1 do
        expect(instance.cached?).to be false
      end
    end

    it 'can be reset' do
      # Fill the cache
      VCR.use_cassette('version') { instance.latest }

      expect { described_class.instance.clear_cache }.to change(
        instance,
        :cached?,
      ).from(true).to(false)
    end
  end
end
