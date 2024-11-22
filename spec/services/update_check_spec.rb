describe UpdateCheck do
  subject(:instance) { described_class.instance }

  before do
    Rails.application.load_seed
    instance.clear_cache!
  end

  describe '.latest' do
    subject(:latest) { instance.latest }

    before { allow(Rails.logger).to receive(:info) }

    context 'when the request succeeds', vcr: { cassette_name: 'version' } do
      it do
        is_expected.to eq(
          { version: 'v0.15.1', registration_status: 'unregistered' },
        )
      end

      it 'has shortcuts' do
        expect(instance.latest_version).to eq('v0.15.1')
        expect(instance.registration_status).to eq('unregistered')
        expect(instance).to be_unregistered
      end

      it 'adds logging' do
        latest

        expect(Rails.logger).to have_received(:info).with(
          'Checked for update availability, valid for 720 minutes',
        )
      end
    end

    context 'when the request fails' do
      before do
        stub_request(:get, 'https://update.solectrus.de').to_return(
          status: [500, 'Something went wrong'],
        )
        allow(Rails.logger).to receive(:error)
      end

      it { is_expected.to eq(registration_status: 'unknown') }

      it 'has no version' do
        expect(instance.latest_version).to be_nil
      end

      it 'has unknown shortcuts' do
        expect(instance.registration_status).to eq('unknown')
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

      it { is_expected.to eq(registration_status: 'unknown') }

      it 'has no version' do
        expect(instance.latest_version).to be_nil
      end

      it 'has blank shortcuts' do
        expect(instance.registration_status).to eq('unknown')
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

      it { is_expected.to eq(registration_status: 'unknown') }

      it 'has no version' do
        expect(instance.latest_version).to be_nil
      end

      it 'has blank shortcuts' do
        expect(instance.registration_status).to eq('unknown')
      end

      it 'logs the error' do
        latest

        expect(Rails.logger).to have_received(:error).with(
          'UpdateCheck failed with SSL error: Exception from WebMock',
        ).once
      end
    end

    context 'when response cannot be parsed',
            vcr: {
              cassette_name: 'version',
            } do
      before do
        allow(JSON).to receive(:parse).and_raise(JSON::ParserError)
        allow(Rails.logger).to receive(:error)
      end

      it { is_expected.to eq(registration_status: 'unknown') }

      it 'has no version' do
        expect(instance.latest_version).to be_nil
      end

      it 'has blank shortcuts' do
        expect(instance.registration_status).to eq('unknown')
      end

      it 'logs the error' do
        latest

        expect(Rails.logger).to have_received(:error).with(
          'UpdateCheck failed: JSON::ParserError',
        ).once
      end
    end

    context 'when response is invalid', vcr: { cassette_name: 'version' } do
      before do
        allow(JSON).to receive(:parse).and_return({ foo: 42 })
        allow(Rails.logger).to receive(:error)
      end

      it { is_expected.to eq(registration_status: 'unknown') }

      it 'has no version' do
        expect(instance.latest_version).to be_nil
      end

      it 'has blank shortcuts' do
        expect(instance.registration_status).to eq('unknown')
      end

      it 'logs the error' do
        latest

        expect(Rails.logger).to have_received(:error).with(
          'UpdateCheck failed: Invalid response',
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

  describe '#simple_prompt?' do
    subject { instance.simple_prompt? }

    let(:headers) { { 'Cache-Control' => 'max-age=43200, private' } }

    context 'when unregistered' do
      before do
        stub_request(:get, 'https://update.solectrus.de').to_return(
          headers:,
          body: {
            version: 'v0.16.0',
            registration_status: 'unregistered',
            prompt: true,
          }.to_json,
        )
      end

      it { is_expected.to be true }
    end

    context 'when registered only' do
      before do
        stub_request(:get, 'https://update.solectrus.de').to_return(
          headers:,
          body: {
            version: 'v0.16.0',
            registration_status: 'complete',
            prompt: true,
          }.to_json,
        )
      end

      it { is_expected.to be true }
    end

    context 'when registered and eligible for free' do
      before do
        stub_request(:get, 'https://update.solectrus.de').to_return(
          headers:,
          body: { version: 'v0.16.0', registration_status: 'complete' }.to_json,
        )
      end

      it { is_expected.to be false }
    end

    context 'when registered and sponsoring' do
      before do
        stub_request(:get, 'https://update.solectrus.de').to_return(
          headers:,
          body: {
            version: 'v0.16.0',
            registration_status: 'complete',
            subscription_plan: 'sponsoring',
          }.to_json,
        )
      end

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
      allow(Rails.logger).to receive(:error)

      # The first request will be cached
      VCR.use_cassette('version') { expect(instance.latest).to be_present }

      # The second request is cached, so the cassette is not used
      expect(instance).to be_cached
      expect(instance.latest).to be_present

      # The cache expires after some time
      travel 12.hours + 1.second do
        expect(instance).not_to be_cached

        # New request is made
        instance.latest
        expect(Rails.logger).to have_received(:error).with(
          /An HTTP request has been made/,
        )
      end
    end

    it 'can be reset' do
      allow(Rails.logger).to receive(:error)

      # Fill the cache
      VCR.use_cassette('version') { instance.latest }

      expect { described_class.instance.clear_cache! }.to change(
        instance,
        :cached?,
      ).from(true).to(false)

      expect(Rails.logger).not_to have_received(:error)
    end
  end
end
