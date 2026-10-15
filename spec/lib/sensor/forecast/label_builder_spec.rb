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

      it 'names tomorrow by its weekday' do
        expect(labels.second[:lines].first[:text]).to eq(
          I18n.l(Date.tomorrow, format: '%A'),
        )
      end
    end
  end

  describe 'with temp_range value_key' do
    subject(:texts) do
      label_builder.build_labels.first[:lines].map { "#{_1[:text]}#{_1[:suffix]}" }
    end

    let(:label_builder) do
      described_class.new(
        temp_forecast_data,
        today_analyzer,
        value_key: :temp_range,
      )
    end

    let(:temp_forecast_data) do
      {
        Date.parse('2024-01-15') => {
          noon_timestamp: Time.zone.parse('2024-01-15 12:00').to_i * 1000,
          **temps,
        },
      }
    end

    let(:temps) { { min_temp: 8.4, max_temp: 18.5 } }

    it 'shows max above min, rounded, without a unit line' do
      expect(texts.drop(1)).to eq(%w[19° 8°])
    end

    it 'keeps the degree sign out of the centered text' do
      lines = label_builder.build_labels.first[:lines].drop(1)
      expect(lines.pluck(:text, :suffix)).to eq([%w[19 °], %w[8 °]])
    end

    context 'with negative temperatures' do
      let(:temps) { { min_temp: -5.6, max_temp: -0.3 } }

      it 'keeps the sign, but not for zero' do
        expect(texts.drop(1)).to eq(%w[0° -6°])
      end
    end

    context 'without temperatures' do
      let(:temps) { {} }

      it 'shows the day only' do
        expect(texts.size).to eq(1)
      end
    end
  end
end
