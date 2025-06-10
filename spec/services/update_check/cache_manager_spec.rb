describe UpdateCheck::CacheManager do
  subject(:cache_manager) { described_class.new }

  include_context 'with cache'

  let(:test_data) { { version: 'v1.0.0', registration_status: 'complete' } }
  let(:cache_key) { cache_manager.cache_key }

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
        cache_manager.set(test_data, expires_at: 1.hour.from_now)
        Rails.cache.clear # Clear Rails cache but keep local cache
      end

      it 'returns data from local cache' do
        expect(result).to eq(test_data)
      end
    end

    context 'when only Rails cache exists' do
      before do
        Rails.cache.write(cache_key, test_data, expires_at: 1.hour.from_now)
      end

      it 'returns data from Rails cache' do
        expect(result).to eq(test_data)
      end

      it 'populates local cache for subsequent calls' do
        # First call reads from Rails cache
        expect(result).to eq(test_data)

        # Clear Rails cache
        Rails.cache.clear

        # Second call should still work from local cache
        expect(cache_manager.get).to eq(test_data)
      end
    end

    context 'when local cache is expired but Rails cache is valid' do
      before do
        # Set data with local cache expiring first
        cache_manager.set(test_data, expires_at: 1.hour.from_now)

        travel 6.minutes do
          # Local cache expires after 5 minutes, Rails cache after 1 hour
          Rails.cache.write(cache_key, test_data, expires_in: 55.minutes)
        end
      end

      it 'returns data from Rails cache' do
        travel 6.minutes do
          expect(result).to eq(test_data)
        end
      end
    end

    context 'when both caches are expired' do
      before do
        # Set very short expiration times
        cache_manager.set(test_data, expires_at: 1.second.from_now)
        # Wait for both caches to expire
        travel 6.minutes
      end

      it 'returns nil because both caches are expired' do
        # Local cache expires after 5 minutes, Rails cache after 1 second
        expect(result).to be_nil
      end
    end
  end

  describe '#set' do
    let(:expires_at) { 2.hours.from_now }

    it 'stores data in both local and Rails cache' do
      cache_manager.set(test_data, expires_at: expires_at)

      expect(Rails.cache.read(cache_key)).to eq(test_data)
      expect(cache_manager.get).to eq(test_data)
    end

    it 'sets correct expiration for Rails cache' do
      cache_manager.set(test_data, expires_at: expires_at)

      travel 1.hour do
        expect(Rails.cache.read(cache_key)).to eq(test_data)
      end

      travel 3.hours do
        expect(Rails.cache.read(cache_key)).to be_nil
      end
    end

    it 'sets 5-minute expiration for local cache regardless of expires_in' do
      cache_manager.set(test_data, expires_at: 1.day.from_now)

      travel 4.minutes do
        expect(cache_manager.cached_local?).to be true
      end

      travel 6.minutes do
        expect(cache_manager.cached_local?).to be false
      end
    end
  end

  describe '#delete' do
    before { cache_manager.set(test_data, expires_at: 1.hour.from_now) }

    it 'removes data from both caches' do
      expect(cache_manager.cached?).to be true

      cache_manager.delete

      expect(cache_manager.cached?).to be false
      expect(Rails.cache.read(cache_key)).to be_nil
    end
  end

  describe '#cached_local?' do
    subject { cache_manager.cached_local? }

    context 'when no local cache exists' do
      it { is_expected.to be false }
    end

    context 'when local cache exists and is valid' do
      before { cache_manager.set(test_data, expires_at: 1.hour.from_now) }

      it { is_expected.to be true }
    end

    context 'when local cache exists but is expired' do
      before do
        cache_manager.set(test_data, expires_at: 1.hour.from_now)
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
      before do
        Rails.cache.write(cache_key, test_data, expires_at: 1.hour.from_now)
      end

      it { is_expected.to be true }
    end

    context 'when Rails cache exists but is expired' do
      before do
        Rails.cache.write(cache_key, test_data, expires_in: 1.minute)
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

    context 'when only local cache exists' do
      before do
        cache_manager.set(test_data, expires_at: 1.hour.from_now)
        Rails.cache.clear
      end

      it { is_expected.to be true }
    end

    context 'when only Rails cache exists' do
      before do
        Rails.cache.write(cache_key, test_data, expires_at: 1.hour.from_now)
      end

      it { is_expected.to be true }
    end

    context 'when both caches exist' do
      before { cache_manager.set(test_data, expires_at: 1.hour.from_now) }

      it { is_expected.to be true }
    end

    context 'when local cache is expired but Rails cache is valid' do
      before do
        cache_manager.set(test_data, expires_at: 1.hour.from_now)
        travel 6.minutes do
          Rails.cache.write(cache_key, test_data, expires_in: 55.minutes)
        end
      end

      it 'returns true because Rails cache is still valid' do
        travel 6.minutes do
          expect(cached?).to be true
        end
      end
    end

    context 'when both caches are expired' do
      before do
        cache_manager.set(test_data, expires_at: 1.second.from_now)
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
