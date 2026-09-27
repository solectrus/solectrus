describe Insights::Component, type: :component do
  subject(:component) do
    described_class.new(sensor:, timeframe:, controller_namespace: 'balance')
  end

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

  describe '#running_period?' do
    subject { component.running_period? }

    let(:sensor) { Sensor::Registry[:inverter_power] }

    context 'with the current month' do
      let(:timeframe) { Timeframe.new(Date.current.strftime('%Y-%m')) }

      it { is_expected.to be true }
    end

    context 'with the current year' do
      let(:timeframe) { Timeframe.new(Date.current.year.to_s) }

      it { is_expected.to be true }
    end

    context 'with a past year' do
      let(:timeframe) { Timeframe.new('2020') }

      it { is_expected.to be false }
    end

    context 'with today' do
      let(:timeframe) { Timeframe.day }

      it { is_expected.to be false }
    end
  end

  describe '#inverter_precision' do
    subject { component.inverter_precision }

    let(:sensor) { Sensor::Registry[:inverter_power] }

    before do
      allow(component.insights).to receive(:inverter_sensor_values).and_return(
        [
          { name: :inverter_power_1, value: 1_700, percentage: 0 },
          { name: :inverter_power_2, value: largest, percentage: 100 },
        ],
      )
    end

    context 'when the largest value has no decimals' do
      let(:largest) { 5_986_000 }

      it { is_expected.to eq(0) }
    end

    context 'when the largest value has decimals' do
      let(:largest) { 5_800 }

      it { is_expected.to eq(1) }
    end
  end

  describe '#heading_total' do
    context 'when sensor uses avg aggregation' do
      let(:sensor) { Sensor::Registry[:heatpump_cop] }

      it { expect(component.heading_total).to be_nil }
    end
  end
end
