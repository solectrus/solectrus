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

    context 'with interleaved nil values (sparse sensor on dense grid)' do
      let(:entries) do
        # Hourly forecast sampled on a 15-minute grid: two real samples at
        # 12:00 and 13:00 surrounded by nil-padding from the shared grid.
        [
          [Time.zone.parse('2024-01-15 12:00'), 1000],
          [Time.zone.parse('2024-01-15 12:15'), nil],
          [Time.zone.parse('2024-01-15 12:30'), nil],
          [Time.zone.parse('2024-01-15 12:45'), nil],
          [Time.zone.parse('2024-01-15 13:00'), 1000],
        ]
      end

      it 'integrates between real samples after dropping nils' do
        # Dropping nils leaves two samples one hour apart:
        # 1000 W * 1 h = 1000 Wh (not ~250 Wh from diluted pairing)
        expect(wh).to eq(1000)
      end
    end

    context 'with fewer than two non-nil entries' do
      let(:entries) do
        [
          [Time.zone.parse('2024-01-15 12:00'), 1000],
          [Time.zone.parse('2024-01-15 13:00'), nil],
        ]
      end

      it { is_expected.to eq(0) }
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
