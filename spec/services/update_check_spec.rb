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
      # The whole answer is cached, except the signature and the notifications.
      # The deadlines are absolute times from the recorded answer, so what they
      # mean for the local clock is tested with stubs further down.
      it do
        is_expected.to eq(
          {
            version: 'v1.3.0',
            registration_status: 'unregistered',
            premium_reason: 'intro',
            premium_ends_at: '2026-09-13T17:22:21+02:00',
            registration_reminder_at: '2026-09-02T17:22:21+02:00',
            registration_due_at: '2026-09-06T17:22:21+02:00',
          },
        )
      end

      it 'has shortcuts' do
        expect(instance.latest_version).to eq('v1.3.0')
        expect(instance.registration_status).to eq('unregistered')
        expect(instance).to be_unregistered
      end

      it 'adds logging' do
        latest

        expect(Rails.logger).to have_received(:info).with(
          'Checked for update availability, valid for 720 minutes',
        )
      end

      # The HttpClient builds the User-Agent inside the mutex, and the
      # User-Agent reports feature flags, which call back into `.latest`.
      # Without a re-entrancy guard this deadlocks with "recursive locking".
      it 'does not deadlock when the User-Agent reads feature flags' do
        expect { latest }.not_to raise_error
        expect(instance.latest_version).to eq('v1.3.0')
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

      # Nothing was answered, which is not the same as an answered "no".
      it 'reports that it knows nothing' do
        expect(instance).to be_unknown
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
          'UpdateCheck failed: timeout: execution expired',
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
          'UpdateCheck failed: SSL error: Exception from WebMock',
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
          version: 'v1.3.0',
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
        version: 'v1.3.0',
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
            registration_reminder_at: 3.days.from_now.iso8601,
            prompt: true,
          ),
        )
      end

      # Nothing is expected of a fresh installation yet, so no warning either.
      it { is_expected.to be false }

      it 'is required once the reminder is due' do
        travel 4.days do
          expect(instance).to be_action_required
        end
      end
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
            premium_reason: 'sponsoring',
          ),
        )
      end

      it { is_expected.to be false }
    end
  end

  describe '#premium_reason' do
    include_context 'with signature verification'

    let(:headers) { { 'Cache-Control' => 'max-age=43200, private' } }

    context 'when the server names a reason' do
      before do
        freeze_time
        stub_request(:get, 'https://update.solectrus.de').to_return(
          headers:,
          body: signed_json(
            version: 'v1.3.0',
            registration_status: 'unregistered',
            premium_reason: 'intro',
            premium_ends_at: 2.days.from_now.iso8601,
            trial_available: true,
          ),
        )
      end

      it 'returns it as a symbol' do
        expect(instance.premium_reason).to eq(:intro)
      end

      it 'returns the parsed end date' do
        expect(instance.premium_ends_at).to eq(2.days.from_now.change(usec: 0))
      end

      it 'reports the free trial as available' do
        expect(instance.trial_available?).to be true
      end
    end

    context 'when the server sends no premium fields' do
      before do
        stub_request(:get, 'https://update.solectrus.de').to_return(
          headers:,
          body: signed_json(
            version: 'v1.3.0',
            registration_status: 'complete',
          ),
        )
      end

      it { expect(instance.premium_reason).to be_nil }
      it { expect(instance.premium_ends_at).to be_nil }
      it { expect(instance.trial_available?).to be false }
    end
  end

  # Both deadlines come from the update server as absolute times. Nothing here
  # knows how long a phase lasts, so nothing here can be changed by moving the
  # local clock or the local setup_id.
  describe 'the registration deadlines' do
    include_context 'with signature verification'

    let(:headers) { { 'Cache-Control' => 'max-age=43200, private' } }

    context 'when the answer names both' do
      before do
        stub_request(:get, 'https://update.solectrus.de').to_return(
          headers:,
          body: signed_json(
            version: 'v1.3.0',
            registration_status: 'unregistered',
            registration_reminder_at: 3.days.from_now.iso8601,
            registration_due_at: 7.days.from_now.iso8601,
          ),
        )
      end

      it 'stays quiet before the reminder' do
        expect(instance).not_to be_registration_reminder_due
        expect(instance).not_to be_registration_grace_period_expired
      end

      it 'asks once the reminder is due' do
        travel 4.days do
          expect(instance).to be_registration_reminder_due
          expect(instance).not_to be_registration_grace_period_expired
        end
      end

      it 'locks out once the deadline passed' do
        travel 8.days do
          expect(instance).to be_registration_grace_period_expired
        end
      end

      it 'ignores the local setup_id' do
        Setting.setup_id = 1.year.ago.to_i

        expect(instance).not_to be_registration_reminder_due
        expect(instance).not_to be_registration_grace_period_expired
      end
    end

    # Which is what a registered installation gets, and what every
    # installation gets while the update server is unreachable.
    context 'when the answer names neither' do
      before do
        stub_request(:get, 'https://update.solectrus.de').to_return(
          headers:,
          body: signed_json(
            version: 'v1.3.0',
            registration_status: 'unregistered',
          ),
        )
      end

      it 'enforces nothing' do
        expect(instance.registration_reminder_at).to be_nil
        expect(instance.registration_due_at).to be_nil
        expect(instance).not_to be_registration_reminder_due
        expect(instance).not_to be_registration_grace_period_expired
      end

      # Whatever the local clock says - the app never derives a deadline of
      # its own.
      it 'stays quiet however far the clock moves' do
        travel 1.year do
          expect(instance).not_to be_registration_reminder_due
          expect(instance).not_to be_registration_grace_period_expired
        end
      end
    end
  end

  describe '.snooze_banner!' do
    include_context 'with cache'

    it 'sets status for some time' do
      expect { instance.snooze_banner! }.to change(
        instance,
        :snoozed_banner?,
      ).from(false).to(true)

      travel 24.hours + 1 do
        expect(instance.snoozed_banner?).to be false
      end
    end

    # Two questions, two switches: the registration deadline is not answered by
    # a "maybe later" given to the sponsoring question.
    it 'leaves the sponsoring prompt alone' do
      instance.snooze_banner!

      expect(instance.skipped_prompt?).to be false
    end
  end

  describe '.skip_prompt!' do
    include_context 'with cache'

    it 'leaves the registration banner alone' do
      instance.skip_prompt!

      expect(instance.snoozed_banner?).to be false
    end

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

      # After 12 hours, the cache is stale (past fresh_until) but still
      # within the grace period (usable_until = fresh_until + 24h).
      travel 12.hours + 1.second do
        expect(cached?).to be true

        # A new request is attempted, but fails (no VCR stub). With the
        # stale entry available, the failure is downgraded to a warning
        # and the previous status is kept.
        allow(Rails.logger).to receive(:warn)
        instance.latest

        expect(Rails.logger).to have_received(:warn).with(
          /UpdateCheck failed \(using cached status\)/,
        )
        expect(cached?).to be true
      end

      # After 36 hours (12h fresh + 24h stale grace), the cache is gone.
      travel 36.hours + 1.second do
        expect(cached?).to be false
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
        instance.cache_manager.set(
          sign_data(data),
          fresh_until: 1.hour.from_now,
          usable_until: 25.hours.from_now,
        )
      end

      context 'with valid signed cache' do
        before do
          sign_and_cache(version: 'v1.3.0', registration_status: 'complete')
        end

        it 'returns verified data without signature key' do
          result = instance.latest

          expect(result).to eq(version: 'v1.3.0', registration_status: 'complete')
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
          instance.cache_manager.instance_variable_get(:@local_cache).clear

          result = instance.latest

          expect(result).to eq(version: 'v1.3.0', registration_status: 'complete')
        end
      end

      context 'with tampered cache' do
        before do
          sign_and_cache(version: 'v1.3.0', registration_status: 'complete')

          # Tamper with cached data
          cache_manager = instance.cache_manager
          entry = cache_manager.get
          tampered =
            entry[:data].merge(
              registration_status: 'complete',
              eligible_for_free: true,
            )
          cache_manager.set(
            tampered,
            fresh_until: 1.hour.from_now,
            usable_until: 25.hours.from_now,
          )

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

    describe 'stale-while-error behavior' do
      include_context 'with signature verification'

      let(:headers) { { 'Cache-Control' => 'max-age=43200, private' } }

      def stub_success
        stub_request(:get, 'https://update.solectrus.de').to_return(
          headers:,
          body: signed_json(
            version: 'v1.3.0',
            registration_status: 'complete',
          ),
        )
      end

      def stub_failure
        stub_request(:get, 'https://update.solectrus.de').to_return(
          status: [500, 'Boom'],
        )
      end

      it 'keeps serving the cached status when the server fails within the grace period' do
        stub_success
        instance.latest # primes the cache with fresh data
        expect(instance.registration_status).to eq('complete')

        # 13h later: cache is stale (fresh_until = 12h), still within
        # the 24h grace window.
        travel 13.hours do
          stub_failure
          allow(Rails.logger).to receive(:warn)
          allow(Rails.logger).to receive(:error)

          expect(instance.registration_status).to eq('complete')
          expect(Rails.logger).to have_received(:warn).with(
            /UpdateCheck failed \(using cached status\)/,
          )
          expect(Rails.logger).not_to have_received(:error)
        end
      end

      it 'switches to unknown once the 24h grace period is exhausted' do
        stub_success
        instance.latest

        # 12h fresh + 24h grace + buffer = past usable_until
        travel 36.hours + 1.minute do
          stub_failure
          allow(Rails.logger).to receive(:error)

          expect(instance.registration_status).to eq('unknown')
          expect(Rails.logger).to have_received(:error).with(
            /UpdateCheck failed:/,
          )
        end
      end

      it 'throttles repeated retries during the stale phase' do
        stub_success
        instance.latest

        travel 13.hours do
          stub_failure
          allow(Rails.logger).to receive(:warn)

          # First call attempts HTTP and fails
          instance.latest
          expect(WebMock).to have_requested(:get, 'https://update.solectrus.de').twice

          # Subsequent calls within 15 min do NOT attempt HTTP
          5.times { instance.latest }
          expect(WebMock).to have_requested(:get, 'https://update.solectrus.de').twice
        end

        # After 15 min, the throttle releases
        travel 13.hours + 16.minutes do
          instance.latest
          expect(WebMock).to have_requested(:get, 'https://update.solectrus.de').times(3)
        end
      end

      it 'treats a legacy/corrupted cache entry as missing and re-fetches' do
        # Simulate a leftover entry from the pre-stale-while-error code
        # path (flat hash without :data/:fresh_until wrapper).
        Rails.cache.write(
          cache_manager.cache_key,
          { version: 'old', registration_status: 'complete' },
          expires_in: 1.hour,
        )
        cache_manager.instance_variable_get(:@local_cache).clear

        stub_success

        expect { instance.latest }.not_to raise_error
        expect(instance.registration_status).to eq('complete')
      end

      it 'treats an entry with a non-time fresh_until as missing' do
        # Defensive guard: a corrupted fresh_until must not crash
        # Time.current < ... comparisons.
        Rails.cache.write(
          cache_manager.cache_key,
          { data: { registration_status: 'complete' }, fresh_until: 'broken' },
          expires_in: 1.hour,
        )
        cache_manager.instance_variable_get(:@local_cache).clear

        stub_success

        expect { instance.latest }.not_to raise_error
        expect(instance.registration_status).to eq('complete')
      end

      # The cache store belongs to the installation, so an entry can outlive the
      # expiry it was written with. The grace period is therefore read from the
      # entry itself, which is the thing that carries the grant.
      it 'switches to unknown when the entry outlives its stale phase' do
        stub_success
        instance.latest

        travel 13.hours do
          entry = Rails.cache.read(cache_manager.cache_key)
          Rails.cache.write(
            cache_manager.cache_key,
            entry.merge(usable_until: 1.minute.ago),
            expires_in: 1.hour,
          )

          stub_failure
          allow(Rails.logger).to receive(:error)

          expect(instance.registration_status).to eq('unknown')
        end
      end

      it 'recovers cleanly when the server comes back during the grace period' do
        stub_success
        instance.latest

        travel 13.hours do
          # First a failure
          stub_failure
          allow(Rails.logger).to receive(:warn)
          instance.latest
        end

        # 16 min later (throttle released), server is healthy again
        travel 13.hours + 16.minutes do
          stub_request(:get, 'https://update.solectrus.de').to_return(
            headers:,
            body: signed_json(
              version: 'v1.3.0',
              registration_status: 'complete',
            ),
          )

          expect(instance.latest_version).to eq('v1.3.0')
        end
      end
    end

    it 'clears sensor cache when the premium status changes' do
      # No premium initially
      allow(described_class).to receive(:premium_reason).and_return(nil)

      # Heatpump sensors should NOT be available without premium
      expect(Sensor::Config.chart_sensors.map(&:name)).not_to include(
        :heatpump_heating_power,
      )

      # Now with a sponsorship
      allow(described_class).to receive(:premium_reason).and_return(:sponsoring)
      described_class.clear_cache!

      # Heatpump sensors should NOW be available
      expect(Sensor::Config.chart_sensors.map(&:name)).to include(
        :heatpump_heating_power,
      )
    end

    # The sensor list is built once per process, and it drops what the feature
    # flags forbid. Nothing else would notice a grant that appears or disappears
    # between two checks, so the list would keep the answer of the check that
    # happened to run first - until the next restart.
    describe 'the sensor cache after a check' do
      include_context 'with signature verification'

      let(:headers) { { 'Cache-Control' => 'max-age=43200, private' } }

      def stub_answer(premium_reason)
        body = { version: 'v1.3.0', registration_status: 'complete' }
        body[:premium_reason] = premium_reason if premium_reason

        stub_request(:get, 'https://update.solectrus.de').to_return(
          headers:,
          body: signed_json(body),
        )
      end

      def heatpump_charted?
        Sensor::Config.chart_sensors.map(&:name).include?(
          :heatpump_heating_power,
        )
      end

      # A sponsor whose first check of the process failed, or ran before the
      # sponsorship was recognized.
      it 'follows a grant that appears' do
        stub_answer(nil)
        instance.latest
        expect(heatpump_charted?).to be(false)

        travel 13.hours do
          stub_answer('sponsoring')
          instance.latest

          expect(heatpump_charted?).to be(true)
        end
      end

      # Every installation meets this at the end of its intro phase.
      it 'follows a grant that disappears' do
        stub_answer('intro')
        instance.latest
        expect(heatpump_charted?).to be(true)

        travel 13.hours do
          stub_answer(nil)
          instance.latest

          expect(heatpump_charted?).to be(false)
        end
      end

      it 'keeps the list when the answer does not change' do
        stub_answer('sponsoring')
        instance.latest

        allow(Sensor::Config).to receive(:clear_cache!)

        travel 13.hours do
          stub_answer('sponsoring')
          instance.latest
        end

        expect(Sensor::Config).not_to have_received(:clear_cache!)
      end
    end
  end
end
