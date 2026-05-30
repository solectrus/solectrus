describe UpdateCheck::CacheManager do
  subject(:cache_manager) { described_class.new }

  include_context 'with cache'

  let(:test_data) { { version: 'v1.2.0', registration_status: 'complete' } }
  let(:cache_key) { cache_manager.cache_key }
  let(:fresh_until) { 1.hour.from_now }
  let(:stale_until) { 25.hours.from_now }

  before do
    allow(Rails.configuration.x.git).to receive(:commit_version).and_return(
      'abc123',
    )
  end

  describe '#get' do
    subject(:result) { cache_manager.get }

    context 'when no cache exists' do
      it { is_expected.to be_nil }
    end

    context 'when only local cache exists and is valid' do
      before do
        cache_manager.set(test_data, fresh_until:, stale_until:)
        Rails.cache.clear # Clear Rails cache but keep local cache
      end

      it 'returns the wrapped entry from local cache' do
        expect(result).to include(
          data: test_data,
          fresh_until: be_within(1.second).of(fresh_until),
          stale_until: be_within(1.second).of(stale_until),
        )
      end
    end

    context 'when only Rails cache exists' do
      before do
        cache_manager.set(test_data, fresh_until:, stale_until:)
        # Clear local cache only
        cache_manager.instance_variable_get(:@local_cache).clear
      end

      it 'returns the wrapped entry from Rails cache' do
        expect(result[:data]).to eq(test_data)
      end

      it 'populates local cache for subsequent calls' do
        expect(result[:data]).to eq(test_data)

        Rails.cache.clear

        expect(cache_manager.get[:data]).to eq(test_data)
      end
    end

    context 'when local cache is expired but Rails cache is valid' do
      before { cache_manager.set(test_data, fresh_until:, stale_until:) }

      it 'returns data from Rails cache' do
        travel 6.minutes do
          expect(result[:data]).to eq(test_data)
        end
      end
    end

    context 'when both caches are expired' do
      before do
        cache_manager.set(
          test_data,
          fresh_until: 1.second.from_now,
          stale_until: 2.seconds.from_now,
        )
        travel 6.minutes
      end

      it { is_expected.to be_nil }
    end
  end

  describe '#set' do
    it 'stores wrapped entry in both caches' do
      cache_manager.set(test_data, fresh_until:, stale_until:)

      expect(Rails.cache.read(cache_key)).to include(data: test_data)
      expect(cache_manager.get[:data]).to eq(test_data)
    end

    it 'sets Rails cache TTL to stale_until' do
      cache_manager.set(test_data, fresh_until:, stale_until:)

      travel 24.hours do
        expect(Rails.cache.read(cache_key)).to be_present
      end

      travel 26.hours do
        expect(Rails.cache.read(cache_key)).to be_nil
      end
    end

    it 'sets 5-minute expiration for local cache regardless of stale_until' do
      cache_manager.set(
        test_data,
        fresh_until:,
        stale_until: 1.day.from_now,
      )

      travel 4.minutes do
        expect(cache_manager.cached_local?).to be true
      end

      travel 6.minutes do
        expect(cache_manager.cached_local?).to be false
      end
    end
  end

  describe '#delete' do
    before { cache_manager.set(test_data, fresh_until:, stale_until:) }

    it 'removes data from both caches' do
      expect(cache_manager.cached?).to be true

      cache_manager.delete

      expect(cache_manager.cached?).to be false
      expect(Rails.cache.read(cache_key)).to be_nil
    end
  end

  describe 'retry throttle' do
    it 'is not throttled by default' do
      expect(cache_manager.retry_throttled?).to be false
    end

    it 'becomes throttled after throttle_retry!' do
      cache_manager.throttle_retry!(15.minutes)
      expect(cache_manager.retry_throttled?).to be true
    end

    it 'expires after the given duration' do
      cache_manager.throttle_retry!(15.minutes)

      travel 14.minutes do
        expect(cache_manager.retry_throttled?).to be true
      end

      travel 16.minutes do
        expect(cache_manager.retry_throttled?).to be false
      end
    end

    it 'can be cleared explicitly' do
      cache_manager.throttle_retry!(15.minutes)
      cache_manager.clear_retry_throttle

      expect(cache_manager.retry_throttled?).to be false
    end
  end

  describe '#cached_local?' do
    subject { cache_manager.cached_local? }

    context 'when no local cache exists' do
      it { is_expected.to be false }
    end

    context 'when local cache exists and is valid' do
      before { cache_manager.set(test_data, fresh_until:, stale_until:) }

      it { is_expected.to be true }
    end

    context 'when local cache exists but is expired' do
      before do
        cache_manager.set(test_data, fresh_until:, stale_until:)
        travel 6.minutes # Local cache expires after 5 minutes
      end

      it { is_expected.to be false }
    end
  end

  describe '#cached_rails?' do
    subject { cache_manager.cached_rails? }

    context 'when no Rails cache exists' do
      it { is_expected.to be false }
    end

    context 'when Rails cache exists and is valid' do
      before { cache_manager.set(test_data, fresh_until:, stale_until:) }

      it { is_expected.to be true }
    end

    context 'when Rails cache exists but is expired' do
      before do
        cache_manager.set(
          test_data,
          fresh_until: 30.seconds.from_now,
          stale_until: 1.minute.from_now,
        )
        travel 2.minutes
      end

      it { is_expected.to be false }
    end
  end

  describe '#cached?' do
    subject(:cached?) { cache_manager.cached? }

    context 'when no cache exists' do
      it { is_expected.to be false }
    end

    context 'when both caches exist' do
      before { cache_manager.set(test_data, fresh_until:, stale_until:) }

      it { is_expected.to be true }
    end

    context 'when local cache is expired but Rails cache is valid' do
      before { cache_manager.set(test_data, fresh_until:, stale_until:) }

      it 'returns true because Rails cache is still valid' do
        travel 6.minutes do
          expect(cached?).to be true
        end
      end
    end

    context 'when both caches are expired' do
      before do
        cache_manager.set(
          test_data,
          fresh_until: 1.second.from_now,
          stale_until: 2.seconds.from_now,
        )
        travel 6.minutes
      end

      it { is_expected.to be false }
    end
  end

  describe '#cache_key' do
    subject(:cache_key) { cache_manager.cache_key }

    it 'includes the git commit version' do
      expect(cache_key).to eq('UpdateCheck:abc123')
    end

    context 'with different commit version' do
      before do
        allow(Rails.configuration.x.git).to receive(:commit_version).and_return(
          'def456',
        )
      end

      it 'reflects the new commit version' do
        expect(cache_key).to eq('UpdateCheck:def456')
      end
    end
  end
end
