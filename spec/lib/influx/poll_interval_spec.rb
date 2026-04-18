describe Influx::PollInterval do
  include_context 'with cache'

  after { described_class.reset! }

  describe '.current' do
    it 'always returns an ActiveSupport::Duration' do
      expect(described_class.current).to be_an(ActiveSupport::Duration)

      10.times { |i| described_class.record((i * 3).seconds.ago) }
      expect(described_class.current).to be_an(ActiveSupport::Duration)

      10.times { described_class.record(10.minutes.ago) }
      expect(described_class.current).to be_an(ActiveSupport::Duration)
    end

    context 'with no recorded data' do
      it 'returns the minimum interval as fallback' do
        expect(described_class.current).to eq(5.seconds)
      end
    end

    context 'with too few recorded samples' do
      it 'returns the minimum interval until enough samples are collected' do
        2.times { described_class.record(2.seconds.ago) }
        expect(described_class.current).to eq(5.seconds)
      end
    end

    context 'with fast-arriving data' do
      before do
        # Simulate polling every 5s while data arrives every ~3s.
        # Ages bounce between 0 and ~3s.
        10.times { |i| described_class.record((i.odd? ? 0 : 3).seconds.ago) }
      end

      it 'stays at the minimum interval' do
        expect(described_class.current).to eq(5.seconds)
      end
    end

    context 'with slowly-arriving data' do
      it 'returns an interval above the minimum' do
        # Simulate data arriving every ~30s; ages bounce between 0 and 30s.
        10.times { |i| described_class.record(((i * 3) % 30).seconds.ago) }
        expect(described_class.current).to be > 5.seconds
      end

      it 'caps at the maximum interval for extremely stale data' do
        10.times { described_class.record(10.minutes.ago) }
        expect(described_class.current).to eq(60.seconds)
      end
    end

    context 'when no new samples arrive for a long time' do
      it 'keeps the last known interval instead of falling back to the minimum' do
        freeze_time
        10.times { described_class.record(40.seconds.ago) }
        stable_interval = described_class.current
        expect(stable_interval).to be > 5.seconds

        travel 1.day
        expect(described_class.current).to eq(stable_interval)
      end
    end
  end

  describe '.record' do
    it 'ignores nil timestamps' do
      expect { described_class.record(nil) }.not_to change(described_class, :current)
    end

    it 'ignores future timestamps (clock skew)' do
      expect { described_class.record(10.seconds.from_now) }.not_to change(
        described_class,
        :current,
      )
    end

    it 'discards oldest samples beyond the buffer size' do
      10.times { described_class.record(50.seconds.ago) }
      expect(described_class.current).to be > 5.seconds

      30.times { described_class.record(1.second.ago) }
      expect(described_class.current).to eq(5.seconds)
    end
  end
end
