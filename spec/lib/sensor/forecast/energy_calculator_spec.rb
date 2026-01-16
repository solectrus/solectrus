describe Sensor::Forecast::EnergyCalculator do
  describe '.calculate_wh' do
    subject(:wh) { described_class.calculate_wh(entries) }

    context 'with empty entries' do
      let(:entries) { [] }

      it { is_expected.to eq(0) }
    end

    context 'with single entry' do
      let(:entries) { [[Time.current, 1000]] }

      it { is_expected.to eq(0) }
    end

    context 'with two entries 1 hour apart at 1000W' do
      let(:entries) do
        [
          [Time.zone.parse('2024-01-15 12:00'), 1000],
          [Time.zone.parse('2024-01-15 13:00'), 1000],
        ]
      end

      it 'calculates energy using left endpoint rule' do
        # Energy = 1000 W * 1 hour = 1000 Wh
        expect(wh).to eq(1000)
      end
    end

    context 'with varying power over 4 intervals' do
      let(:entries) do
        [
          [Time.zone.parse('2024-01-15 10:00'), 500],
          [Time.zone.parse('2024-01-15 10:15'), 1000],
          [Time.zone.parse('2024-01-15 10:30'), 1500],
          [Time.zone.parse('2024-01-15 10:45'), 1000],
          [Time.zone.parse('2024-01-15 11:00'), 500], # not used - right endpoint
        ]
      end

      it 'sums energy for all intervals' do
        # Interval 1: 500 W * 0.25 h = 125 Wh
        # Interval 2: 1000 W * 0.25 h = 250 Wh
        # Interval 3: 1500 W * 0.25 h = 375 Wh
        # Interval 4: 1000 W * 0.25 h = 250 Wh
        # Total: 1000 Wh
        expect(wh).to eq(1000)
      end
    end

    context 'with nil power values' do
      let(:entries) do
        [
          [Time.zone.parse('2024-01-15 12:00'), 1000],
          [Time.zone.parse('2024-01-15 13:00'), nil],
          [Time.zone.parse('2024-01-15 14:00'), 1000],
        ]
      end

      it 'skips intervals with nil power' do
        # First interval: 1000 W * 1 hour = 1000 Wh
        # Second interval: skipped (nil power)
        expect(wh).to eq(1000)
      end
    end

    context 'with unsorted entries' do
      let(:entries) do
        [
          [Time.zone.parse('2024-01-15 13:00'), 500],
          [Time.zone.parse('2024-01-15 12:00'), 1000], # Earlier timestamp
        ]
      end

      it 'sorts entries before calculation' do
        # Should use 1000W for first interval (12:00 -> 13:00)
        expect(wh).to eq(1000)
      end
    end
  end
end
