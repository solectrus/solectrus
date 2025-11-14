describe Sensor::Forecast::Day do
  let(:date) { Date.parse('2024-01-15') }
  let(:day_forecast) { described_class.new(date, entries) }

  describe '#valid?' do
    subject { day_forecast.valid? }

    context 'with sufficient entries spanning 8+ hours' do
      let(:entries) do
        (0..8).map do |hour|
          [Time.zone.parse("2024-01-15 #{hour + 8}:00"), 1000]
        end
      end

      it { is_expected.to be true }
    end

    context 'with only 1 entry' do
      let(:entries) { [[Time.zone.parse('2024-01-15 12:00'), 1000]] }

      it { is_expected.to be false }
    end

    context 'with entries spanning less than 8 hours' do
      let(:entries) do
        [
          [Time.zone.parse('2024-01-15 12:00'), 1000],
          [Time.zone.parse('2024-01-15 15:00'), 1000], # Only 3 hours
        ]
      end

      it { is_expected.to be false }
    end
  end

  describe '#noon_timestamp_ms' do
    let(:entries) do
      [
        [Time.zone.parse('2024-01-15 09:00'), 500],
        [Time.zone.parse('2024-01-15 11:45'), 1500], # Closest to noon
        [Time.zone.parse('2024-01-15 14:00'), 1200],
      ]
    end

    it 'returns timestamp closest to 12:00 in milliseconds' do
      expected_ms = Time.zone.parse('2024-01-15 11:45').to_i * 1000
      expect(day_forecast.noon_timestamp_ms).to eq(expected_ms)
    end
  end

  describe '#total_kwh' do
    subject(:total_kwh) { day_forecast.total_kwh }

    context 'when day is complete (starts near zero, spans 8+ hours)' do
      let(:entries) do
        [
          [Time.zone.parse('2024-01-15 08:00'), 5], # Low power start
          [Time.zone.parse('2024-01-15 12:00'), 2000],
          [Time.zone.parse('2024-01-15 16:00'), 1000],
        ]
      end

      it 'calculates total kWh' do
        # Uses EnergyCalculator - just verify it's called
        expect(total_kwh).to be_a(Integer)
        expect(total_kwh).to be >= 0
      end
    end

    context 'when day is incomplete (high power start)' do
      let(:entries) do
        [
          [Time.zone.parse('2024-01-15 08:00'), 500], # High start
          [Time.zone.parse('2024-01-15 12:00'), 2000],
          [Time.zone.parse('2024-01-15 16:00'), 1000],
        ]
      end

      it 'returns nil for incomplete days (unless today)' do
        expect(total_kwh).to be_nil
      end
    end

    context 'when date is today (regardless of completion)' do
      let(:date) { Date.current }
      let(:entries) do
        [
          [Time.zone.parse("#{Date.current} 08:00"), 500],
          [Time.zone.parse("#{Date.current} 12:00"), 2000],
          [Time.zone.parse("#{Date.current} 16:00"), 1000],
        ]
      end

      it 'calculates total kWh even if day incomplete' do
        expect(total_kwh).to be_a(Integer)
      end
    end
  end
end
