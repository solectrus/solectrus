describe Sensor::Definitions::CustomCostsPv do # rubocop:disable RSpec/SpecFilePathFormat
  subject(:sensor) { described_class.new(1) }

  describe '#calculate_with_prices' do
    subject(:result) { sensor.calculate_with_prices(prices:, **values) }

    let(:prices) { { feed_in: 0.08 } }
    let(:values) { { custom_power_01: 3_000.0, custom_power_01_grid: 1_000.0 } }

    it 'prices the PV share at the feed-in tariff' do
      # (3000 - 1000) Wh = 2 kWh * 0.08
      expect(result).to be_within(0.0001).of(0.16)
    end

    context 'when the grid share exceeds the total' do
      let(:values) { { custom_power_01: 1_000.0, custom_power_01_grid: 1_500.0 } }

      it 'floors the PV share at zero' do
        expect(result).to eq(0)
      end
    end

    context 'without a feed-in price' do
      let(:prices) { {} }

      it { is_expected.to be_nil }
    end

    context 'without the grid share' do
      let(:values) { { custom_power_01: 3_000.0, custom_power_01_grid: nil } }

      it { is_expected.to be_nil }
    end
  end

  describe '#dependencies' do
    it 'names the consumer and its grid share' do
      expect(sensor.dependencies).to eq(%i[custom_power_01 custom_power_01_grid])
    end
  end
end
