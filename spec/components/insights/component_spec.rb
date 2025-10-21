describe Insights::Component, type: :component do
  subject(:component) { described_class.new(sensor:, timeframe:) }

  let(:timeframe) { Timeframe.new('2025-01') }

  describe '#per_day_value?' do
    subject { component.per_day_value? }

    context 'when sensor uses sum aggregation' do
      let(:sensor) { Sensor::Registry[:inverter_power] }

      it { is_expected.to be true }
    end

    context 'when sensor uses avg aggregation' do
      let(:sensor) { Sensor::Registry[:heatpump_cop] }

      it { is_expected.to be false }
    end

    context 'when timeframe is single day' do
      let(:sensor) { Sensor::Registry[:inverter_power] }
      let(:timeframe) { Timeframe.new('2025-01-01') }

      it { is_expected.to be false }
    end

    context 'when sensor is excluded from per_day display' do
      let(:sensor) { Sensor::Registry[:grid_power] }

      it { is_expected.to be false }
    end
  end
end
