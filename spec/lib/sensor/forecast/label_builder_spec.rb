require 'rails_helper'

describe Sensor::Forecast::LabelBuilder do
  let(:today_analyzer) { instance_double(Sensor::Forecast::TodayAnalyzer) }
  let(:label_builder) do
    described_class.new(
      forecast_data,
      today_analyzer,
      value_key: :total_wh,
    )
  end

  let(:forecast_data) do
    {
      Date.parse('2024-01-15') => {
        noon_timestamp: Time.zone.parse('2024-01-15 12:00').to_i * 1000,
        total_wh: 25_000,
      },
      Date.parse('2024-01-16') => {
        noon_timestamp: Time.zone.parse('2024-01-16 12:00').to_i * 1000,
        total_wh: 30_000,
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

    context 'when total_wh is nil' do
      let(:forecast_data) do
        {
          Date.parse('2024-01-15') => {
            noon_timestamp: Time.zone.parse('2024-01-15 12:00').to_i * 1000,
            total_wh: nil,
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
            total_wh: 15_000,
          },
          Date.tomorrow => {
            noon_timestamp:
              Time.zone.parse("#{Date.tomorrow} 12:00").to_i * 1000,
            total_wh: 20_000,
          },
        }
      end

      before do
        allow(today_analyzer).to receive_messages(
          past_production?: true,
          show_today?: true,
          total_wh: 15_000,
        )
      end

      it 'shows total kWh label for today' do
        today_label = labels.first[:lines].find { |l| l[:text]&.include?('15') }
        expect(today_label).to be_present
      end
    end
  end

  describe 'with avg_temp value_key' do
    let(:label_builder) do
      described_class.new(
        temp_forecast_data,
        today_analyzer,
        value_key: :avg_temp,
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

    context 'with negative temperatures' do
      let(:temp_forecast_data) do
        {
          Date.parse('2024-01-15') => {
            noon_timestamp: Time.zone.parse('2024-01-15 12:00').to_i * 1000,
            avg_temp: -5.2,
          },
        }
      end

      it 'formats negative temperature correctly' do
        labels = label_builder.build_labels
        temp_label =
          labels.first[:lines].find { |l| l[:text]&.include?('-5.2') }
        expect(temp_label).to be_present
      end

      it 'includes unit for negative temperature' do
        labels = label_builder.build_labels
        unit_label = labels.first[:lines].find { |l| l[:text] == '°C' }
        expect(unit_label).to be_present
      end
    end

    context 'with zero temperature' do
      let(:temp_forecast_data) do
        {
          Date.parse('2024-01-15') => {
            noon_timestamp: Time.zone.parse('2024-01-15 12:00').to_i * 1000,
            avg_temp: 0.0,
          },
        }
      end

      it 'formats zero temperature correctly' do
        labels = label_builder.build_labels
        temp_label = labels.first[:lines].find { |l| l[:text]&.include?('0') }
        expect(temp_label).to be_present
      end

      it 'includes unit for zero temperature' do
        labels = label_builder.build_labels
        unit_label = labels.first[:lines].find { |l| l[:text] == '°C' }
        expect(unit_label).to be_present
      end
    end
  end
end
