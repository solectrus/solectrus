describe Sensor::Chart::Forecast::TodayAnalyzer do
  # Use real current date/time to avoid date mismatch issues
  let(:current_time) { Time.current }
  let(:analyzer) { described_class.new(forecast_data, current_time:) }

  before { travel_to Time.zone.parse('2024-01-15 14:00') }

  describe '#show_today?' do
    subject { analyzer.show_today? }

    context 'with no forecast data' do
      let(:forecast_data) { nil }

      it { is_expected.to be true }
    end

    context 'with future positive power expected today' do
      let(:forecast_data) do
        {
          Time.zone.parse('2024-01-15 15:00') => 1500, # Future
          Time.zone.parse('2024-01-15 16:00') => 1000,
        }
      end

      it { is_expected.to be true }
    end

    context 'with only past power today' do
      let(:forecast_data) do
        {
          Time.zone.parse('2024-01-15 12:00') => 1500, # Past
          Time.zone.parse('2024-01-15 13:00') => 1000,
        }
      end

      it { is_expected.to be false }
    end

    context 'with future zero power' do
      let(:forecast_data) do
        {
          Time.zone.parse('2024-01-15 15:00') => 0, # Future but zero
          Time.zone.parse('2024-01-15 16:00') => 0,
        }
      end

      it { is_expected.to be false }
    end
  end

  describe '#past_production?' do
    subject { analyzer.past_production? }

    context 'with past positive power today' do
      let(:forecast_data) do
        {
          Time.zone.parse('2024-01-15 12:00') => 1500,
          Time.zone.parse('2024-01-15 13:00') => 1000,
        }
      end

      it { is_expected.to be true }
    end

    context 'with only future power' do
      let(:forecast_data) { { Time.zone.parse('2024-01-15 15:00') => 1500 } }

      it { is_expected.to be false }
    end

    context 'with past zero power' do
      let(:forecast_data) { { Time.zone.parse('2024-01-15 12:00') => 0 } }

      it { is_expected.to be false }
    end
  end

  describe '#remaining_kwh' do
    subject(:remaining_kwh) { analyzer.remaining_kwh }

    context 'with future forecast data in 15-minute intervals' do
      let(:forecast_data) do
        {
          Time.zone.parse('2024-01-15 14:00') => 1200, # Now (not included)
          Time.zone.parse('2024-01-15 14:15') => 1500, # Future
          Time.zone.parse('2024-01-15 14:30') => 1800,
          Time.zone.parse('2024-01-15 14:45') => 1500,
          Time.zone.parse('2024-01-15 15:00') => 1000,
        }
      end

      it 'calculates energy only for future intervals' do
        # 14:15-14:30: 1.5 kW * 0.25 h = 0.375 kWh
        # 14:30-14:45: 1.8 kW * 0.25 h = 0.45 kWh
        # 14:45-15:00: 1.5 kW * 0.25 h = 0.375 kWh
        # Total: 1.2 kWh -> rounds to 1
        expect(remaining_kwh).to eq(1)
      end
    end

    context 'with no future data' do
      let(:forecast_data) { { Time.zone.parse('2024-01-15 12:00') => 1500 } }

      it { is_expected.to eq(0) }
    end
  end
end
