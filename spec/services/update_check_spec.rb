describe UpdateCheck do
  subject(:instance) { described_class.instance }

  before do
    Rails.application.load_seed
    instance.clear_cache!
  end

  # Some helper methods to check the cache
  delegate :cached?, to: :instance
  delegate :cached_local?, to: :instance
  delegate :cached_rails?, to: :instance

  ##############

  describe '.latest' do
    subject(:latest) { instance.latest }

    before { allow(Rails.logger).to receive(:info) }

    context 'when the request succeeds', vcr: { cassette_name: 'version' } do
      it do
        is_expected.to eq(
          { version: 'v0.20.1', registration_status: 'unregistered' },
        )
      end

      it 'handles grace period' do
        expect(instance).not_to be_registration_grace_period_expired

        travel 15.days do
          expect(instance).to be_registration_grace_period_expired
        end
      end

      it 'has shortcuts' do
        expect(instance.latest_version).to eq('v0.20.1')
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

    it 'stores skip information independently of main cache' do
      # Ensure we start with clean caches
      instance.clear_cache!
      expect(instance.skipped_prompt?).to be false

      # Skip the prompt
      instance.skip_prompt!
      expect(instance.skipped_prompt?).to be true

      # Main cache should remain empty since we didn't fetch data
      expect(cached?).to be false
    end
  end

  describe 'caching' do
    include_context 'with cache'

    it 'caches the version' do
      allow(Rails.logger).to receive(:error)

      # We start with an empty cache
      expect(cached?).to be false

      # The first request will fill the cache
      VCR.use_cassette('version') { expect(instance.latest).to be_present }
      expect(cached?).to be true

      # The second request will be served from the cache
      expect(instance.latest).to be_present

      # After one minute, both the local cache and the Rails cache are still filled
      travel 1.minute do
        expect(cached?).to be true
        expect(cached_local?).to be true
        expect(cached_rails?).to be true
      end

      # After 5 minutes, the local cache is empty, but the Rails cache is still filled
      travel 5.minutes + 1.second do
        expect(cached?).to be true
        expect(cached_local?).to be false
        expect(cached_rails?).to be true

        # The next access will fill the local cache again (from the Rails cache)
        instance.latest
        expect(cached_local?).to be true
        expect(cached_rails?).to be true
      end

      # After 12 hours, both caches are empty
      travel 12.hours + 1.second do
        expect(cached?).to be false

        # New request is made (but fails because of VCR)
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

      expect { described_class.instance.clear_cache! }.to change {
        cached?
      }.from(true).to(false)

      expect(Rails.logger).not_to have_received(:error)
    end
  end
end
