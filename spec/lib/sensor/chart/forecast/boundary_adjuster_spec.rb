describe Sensor::Chart::Forecast::BoundaryAdjuster do
  describe '.add_boundaries!' do
    let(:data) do
      {
        Time.zone.parse('2024-01-15 10:00') => 500,
        Time.zone.parse('2024-01-15 11:00') => 1500,
        Time.zone.parse('2024-01-15 12:00') => 2000,
        Time.zone.parse('2024-01-15 13:00') => 1500,
        Time.zone.parse('2024-01-15 14:00') => 500,
      }
    end
    let(:series_raw_data) { { [:inverter_power_forecast] => data } }

    it 'adds zero values 15 minutes before first non-zero and after last non-zero' do
      described_class.add_boundaries!(series_raw_data)

      expect(data[Time.zone.parse('2024-01-15 09:45')]).to eq(0.0)
      expect(data[Time.zone.parse('2024-01-15 14:15')]).to eq(0.0)
    end

    it 'does not overwrite existing values' do
      data[Time.zone.parse('2024-01-15 09:45')] = 999
      described_class.add_boundaries!(series_raw_data)

      expect(data[Time.zone.parse('2024-01-15 09:45')]).to eq(999)
    end

    it 'handles multiple days independently' do
      data[Time.zone.parse('2024-01-16 10:00')] = 600
      data[Time.zone.parse('2024-01-16 12:00')] = 1200

      described_class.add_boundaries!(series_raw_data)

      expect(data[Time.zone.parse('2024-01-15 09:45')]).to eq(0.0)
      expect(data[Time.zone.parse('2024-01-15 14:15')]).to eq(0.0)
      expect(data[Time.zone.parse('2024-01-16 09:45')]).to eq(0.0)
      expect(data[Time.zone.parse('2024-01-16 12:15')]).to eq(0.0)
    end

    context 'with values below threshold (0.01)' do
      let(:data) do
        {
          Time.zone.parse('2024-01-15 10:00') => 0.005, # Below threshold
          Time.zone.parse('2024-01-15 11:00') => 1500,
        }
      end

      it 'ignores near-zero values when finding boundaries' do
        described_class.add_boundaries!(series_raw_data)

        # Boundary should be around 11:00 (first truly non-zero), not 10:00
        expect(data[Time.zone.parse('2024-01-15 10:45')]).to eq(0.0)
        expect(data[Time.zone.parse('2024-01-15 09:45')]).to be_nil
      end
    end
  end
end
