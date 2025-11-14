require 'rails_helper'

describe Sensor::Forecast::LabelBuilder do
  let(:today_analyzer) do
    instance_double(Sensor::Forecast::TodayAnalyzer)
  end
  let(:label_builder) do
    described_class.new(
      forecast_data,
      today_analyzer,
      value_key: :total_kwh,
      unit: 'kWh',
      precision: 0,
    )
  end

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
          total_kwh: 15,
        )
      end

      it 'shows total kWh label instead of remaining' do
        total_label = labels.first[:lines].find { |l| l[:text]&.include?('15') }
        expect(total_label).to be_present
      end
    end
  end

  describe 'with precision option' do
    let(:label_builder) do
      described_class.new(
        temp_forecast_data,
        today_analyzer,
        value_key: :avg_temp,
        unit: '°C',
        precision: 1,
      )
    end

    let(:temp_forecast_data) do
      {
        Date.parse('2024-01-15') => {
          noon_timestamp: Time.zone.parse('2024-01-15 12:00').to_i * 1000,
          avg_temp: 18.5,
        },
      }
    end

    it 'formats temperature with decimal precision' do
      labels = label_builder.build_labels
      temp_label = labels.first[:lines].find { |l| l[:text]&.include?('18.5') }
      expect(temp_label).to be_present
    end

    it 'includes correct unit' do
      labels = label_builder.build_labels
      unit_label = labels.first[:lines].find { |l| l[:text] == '°C' }
      expect(unit_label).to be_present
    end
  end
end
