describe Sensor::Forecast::EnergyCalculator do
  describe '.calculate_kwh' do
    subject(:kwh) { described_class.calculate_kwh(entries) }

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
          [Time.zone.parse('2024-01-15 12:00'), 1000], # 1 kW
          [Time.zone.parse('2024-01-15 13:00'), 1000],
        ]
      end

      it 'calculates energy using left endpoint rule' do
        # Energy = 1 kW * 1 hour = 1 kWh
        expect(kwh).to eq(1)
      end
    end

    context 'with varying power over 4 intervals' do
      let(:entries) do
        [
          [Time.zone.parse('2024-01-15 10:00'), 500], # 0.5 kW
          [Time.zone.parse('2024-01-15 10:15'), 1000], # 1.0 kW
          [Time.zone.parse('2024-01-15 10:30'), 1500], # 1.5 kW
          [Time.zone.parse('2024-01-15 10:45'), 1000], # 1.0 kW
          [Time.zone.parse('2024-01-15 11:00'), 500], # 0.5 kW (not used - right endpoint)
        ]
      end

      it 'sums energy for all intervals' do
        # Interval 1: 0.5 kW * 0.25 h = 0.125 kWh
        # Interval 2: 1.0 kW * 0.25 h = 0.25 kWh
        # Interval 3: 1.5 kW * 0.25 h = 0.375 kWh
        # Interval 4: 1.0 kW * 0.25 h = 0.25 kWh
        # Total: 1.0 kWh (rounds to 1)
        expect(kwh).to eq(1)
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
        # First interval: 1 kW * 1 hour = 1 kWh
        # Second interval: skipped (nil power)
        expect(kwh).to eq(1)
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
        expect(kwh).to eq(1)
      end
    end
  end
end
