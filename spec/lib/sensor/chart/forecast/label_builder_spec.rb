describe Sensor::Chart::Forecast::LabelBuilder do
  let(:today_analyzer) do
    instance_double(Sensor::Chart::Forecast::TodayAnalyzer)
  end
  let(:label_builder) { described_class.new(forecast_data, today_analyzer) }

  let(:forecast_data) do
    {
      Date.parse('2024-01-15') => {
        noon_timestamp: Time.zone.parse('2024-01-15 12:00').to_i * 1000,
        total_kwh: 25,
      },
      Date.parse('2024-01-16') => {
        noon_timestamp: Time.zone.parse('2024-01-16 12:00').to_i * 1000,
        total_kwh: 30,
      },
    }
  end

  before do
    allow(today_analyzer).to receive_messages(
      past_production?: false,
      show_today?: true,
    )
  end

  describe '#build_labels' do
    subject(:labels) { label_builder.build_labels }

    it 'returns label for each day' do
      expect(labels.size).to eq(2)
    end

    it 'includes noon timestamp' do
      expect(labels.first[:x]).to eq(
        Time.zone.parse('2024-01-15 12:00').to_i * 1000,
      )
    end

    it 'includes day label and energy labels' do
      expect(labels.first[:lines]).to be_an(Array)
      expect(labels.first[:lines].size).to be >= 1
    end

    context 'when total_kwh is nil' do
      let(:forecast_data) do
        {
          Date.parse('2024-01-15') => {
            noon_timestamp: Time.zone.parse('2024-01-15 12:00').to_i * 1000,
            total_kwh: nil,
          },
        }
      end

      it 'includes only day label without energy labels' do
        expect(labels.first[:lines].size).to eq(1)
      end
    end

    context 'when date is today with past production' do
      let(:forecast_data) do
        {
          Date.current => {
            noon_timestamp:
              Time.zone.parse("#{Date.current} 12:00").to_i * 1000,
            total_kwh: 15,
          },
        }
      end

      before do
        allow(today_analyzer).to receive_messages(
          past_production?: true,
          show_today?: true,
          remaining_kwh: 8,
        )
      end

      it 'shows remaining kWh label instead of total' do
        remaining_label =
          labels.first[:lines].find { |l| l[:text]&.include?('8') }
        expect(remaining_label).to be_present
      end
    end
  end
end
