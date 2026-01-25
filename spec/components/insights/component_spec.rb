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

  describe '#show_total?' do
    subject { component.show_total? }

    let(:sensor) { Sensor::Registry[sensor_name] }

    context 'when sensor uses avg aggregation' do
      let(:sensor_name) { :heatpump_cop }

      it { is_expected.to be false }
    end

    context 'when sensor is inverter_power' do
      let(:sensor_name) { :inverter_power }

      # inverter_power already shows total in its dedicated section
      it { is_expected.to be false }
    end

    context 'when sensor is house_power' do
      let(:sensor_name) { :house_power }

      # house_power already shows total in its dedicated section
      it { is_expected.to be false }
    end
  end
end
