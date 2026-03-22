describe UpdateCheck do
  subject(:instance) { described_class.instance }

  before do
    # Allow HTTP fetching in these tests (normally skipped in local environments)
    allow(described_class).to receive(:skip_http?).and_return(false)
    instance.clear_cache!
  end

  let(:cache_manager) { instance.cache_manager }

  delegate :cached?, :cached_local?, :cached_rails?, to: :cache_manager

  ##############

  describe '.latest' do
    subject(:latest) { instance.latest }

    before { allow(Rails.logger).to receive(:info) }

    context 'when the request succeeds', vcr: { cassette_name: 'version' } do
      it do
        is_expected.to eq(
          { version: 'v1.1.1', registration_status: 'unregistered' },
        )
      end

      it 'handles grace period' do
        expect(instance).not_to be_registration_grace_period_expired

        travel 15.days do
          expect(instance).to be_registration_grace_period_expired
        end
      end

      it 'handles missing setup_id by seeding it' do
        Setting.where(var: 'setup_id').delete_all
        Setting.clear_cache

        expect(Setting.setup_id).to be_nil
        expect(instance).not_to be_registration_grace_period_expired
        expect(Setting.setup_id).to be_present
      end

      it 'has shortcuts' do
        expect(instance.latest_version).to eq('v1.1.1')
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

  describe 'notifications' do
    include_context 'with signature verification'

    let(:headers) { { 'Cache-Control' => 'max-age=43200, private' } }

    let(:notifications) do
      [
        {
          id: 123,
          title: 'Test Notification',
          body: 'This is a test notification',
          published_at: '2025-01-15T10:00:00Z',
        },
      ]
    end

    before do
      stub_request(:get, 'https://update.solectrus.de').to_return(
        headers:,
        body: signed_json(
          version: 'v1.1.1',
          registration_status: 'complete',
          notifications:,
        ),
      )
    end

    it 'imports notifications to the database' do
      expect { instance.latest }.to change(Notification, :count).by(1)

      notification = Notification.find(123)
      expect(notification.title).to eq('Test Notification')
    end

    it 'does not include notifications in cached data' do
      result = instance.latest

      expect(result).not_to have_key(:notifications)
      expect(result).to eq(
        version: 'v1.1.1',
        registration_status: 'complete',
      )
    end
  end

  describe '#prompt?' do
    subject { instance.prompt? }

    context 'when not registered' do
      it { is_expected.to be false }
    end
  end

  describe '#action_required?' do
    subject { instance.action_required? }

    include_context 'with signature verification'

    let(:headers) { { 'Cache-Control' => 'max-age=43200, private' } }

    context 'when unregistered' do
      before do
        stub_request(:get, 'https://update.solectrus.de').to_return(
          headers:,
          body: signed_json(
            version: 'v0.16.0',
            registration_status: 'unregistered',
            prompt: true,
          ),
        )
      end

      it { is_expected.to be true }
    end

    context 'when registered only' do
      before do
        stub_request(:get, 'https://update.solectrus.de').to_return(
          headers:,
          body: signed_json(
            version: 'v0.16.0',
            registration_status: 'complete',
            prompt: true,
          ),
        )
      end

      it { is_expected.to be true }
    end

    context 'when registered and unprompted' do
      before do
        stub_request(:get, 'https://update.solectrus.de').to_return(
          headers:,
          body: signed_json(
            version: 'v0.16.0',
            registration_status: 'complete',
          ),
        )
      end

      it { is_expected.to be false }
    end

    context 'when registered and sponsoring' do
      before do
        stub_request(:get, 'https://update.solectrus.de').to_return(
          headers:,
          body: signed_json(
            version: 'v0.16.0',
            registration_status: 'complete',
            subscription_plan: 'sponsoring',
          ),
        )
      end

      it { is_expected.to be false }
    end
  end

  describe '#eligible_for_free?' do
    subject(:eligible_for_free) { instance.eligible_for_free? }

    include_context 'with signature verification'

    let(:headers) { { 'Cache-Control' => 'max-age=43200, private' } }

    context 'when server returns eligible_for_free' do
      before do
        stub_request(:get, 'https://update.solectrus.de').to_return(
          headers:,
          body: signed_json(
            version: 'v1.1.1',
            registration_status: 'complete',
            eligible_for_free: true,
          ),
        )
      end

      it { is_expected.to be true }
    end

    context 'when server does not return eligible_for_free' do
      before do
        stub_request(:get, 'https://update.solectrus.de').to_return(
          headers:,
          body: signed_json(
            version: 'v1.1.1',
            registration_status: 'complete',
          ),
        )
      end

      it { is_expected.to be false }
    end
  end

  describe '#free_trial?' do
    subject(:free_trial) { instance.free_trial? }

    include_context 'with signature verification'

    let(:headers) { { 'Cache-Control' => 'max-age=43200, private' } }

    context 'when free_trial_ends_at is in the future' do
      before do
        stub_request(:get, 'https://update.solectrus.de').to_return(
          headers:,
          body: signed_json(
            version: 'v1.1.1',
            registration_status: 'complete',
            free_trial_ends_at: 30.days.from_now.iso8601,
          ),
        )
      end

      it { is_expected.to be true }

      it 'returns parsed end date' do
        expect(instance.free_trial_ends_at).to be_within(1.second).of(30.days.from_now)
      end
    end

    context 'when free_trial_ends_at is in the past' do
      before do
        stub_request(:get, 'https://update.solectrus.de').to_return(
          headers:,
          body: signed_json(
            version: 'v1.1.1',
            registration_status: 'complete',
            free_trial_ends_at: 1.day.ago.iso8601,
          ),
        )
      end

      it { is_expected.to be false }
    end

    context 'when free_trial_ends_at is not present' do
      before do
        stub_request(:get, 'https://update.solectrus.de').to_return(
          headers:,
          body: signed_json(
            version: 'v1.1.1',
            registration_status: 'complete',
          ),
        )
      end

      it { is_expected.to be false }

      it 'returns nil for free_trial_ends_at' do
        expect(instance.free_trial_ends_at).to be_nil
      end
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

    describe 'signature verification on cache read' do
      include_context 'with signature verification'

      def sign_and_cache(data)
        instance
          .instance_variable_get(:@cache_manager)
          .set(sign_data(data), expires_at: 1.hour.from_now)
      end

      context 'with valid signed cache' do
        before do
          sign_and_cache(version: 'v1.1.1', registration_status: 'complete')
        end

        it 'returns verified data without signature key' do
          result = instance.latest

          expect(result).to eq(version: 'v1.1.1', registration_status: 'complete')
          expect(result).not_to have_key(:signature)
        end

        it 'memoizes the result on subsequent reads' do
          instance.latest
          expect_any_instance_of(UpdateCheck::SignatureVerifier) # rubocop:disable RSpec/AnyInstance
            .not_to receive(:verify!)

          instance.latest
        end

        it 're-verifies successfully after process restart' do
          # Simulate process restart: clear memoized state and local cache,
          # but keep Rails cache (like Redis in production)
          instance.__send__(:reset_verified_cache!)
          instance
            .instance_variable_get(:@cache_manager)
            .instance_variable_get(:@local_cache)
            .clear

          result = instance.latest

          expect(result).to eq(version: 'v1.1.1', registration_status: 'complete')
        end
      end

      context 'with tampered cache' do
        before do
          sign_and_cache(version: 'v1.1.1', registration_status: 'complete')

          # Tamper with cached data
          cache_manager = instance.instance_variable_get(:@cache_manager)
          tampered = cache_manager.get.merge(registration_status: 'complete', eligible_for_free: true)
          cache_manager.set(tampered, expires_at: 1.hour.from_now)

          allow(Rails.logger).to receive(:error)
        end

        it 'clears cache and returns unknown status' do
          result = instance.latest

          expect(result).to eq(registration_status: 'unknown')
        end

        it 'logs the tampering' do
          instance.latest

          expect(Rails.logger).to have_received(:error).with(
            'UpdateCheck: invalid signature in cache, clearing',
          )
        end
      end
    end

    it 'clears sensor cache when sponsoring status changes' do
      # No sponsoring initially
      allow(described_class).to receive(:sponsoring?).and_return(false)

      # Heatpump sensors should NOT be available without sponsoring
      expect(Sensor::Config.chart_sensors.map(&:name)).not_to include(
        :heatpump_heating_power,
      )

      # Now with sponsoring
      allow(described_class).to receive(:sponsoring?).and_return(true)
      described_class.clear_cache!

      # Heatpump sensors should NOW be available
      expect(Sensor::Config.chart_sensors.map(&:name)).to include(
        :heatpump_heating_power,
      )
    end
  end
end
