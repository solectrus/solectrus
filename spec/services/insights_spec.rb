describe Insights do
  subject(:insights) { described_class.new(sensor:, timeframe:) }

  let(:timeframe) { Timeframe.new('2025') }

  describe '#value' do
    subject { insights.value }

    context 'when sensor is :inverter_power' do
      let(:sensor) { :inverter_power }

      before do
        create_summary(
          date: Date.new(2025, 1, 1),
          values: [[:inverter_power_1, :sum, 1000]],
        )
        create_summary(
          date: Date.new(2025, 1, 2),
          values: [[:inverter_power_1, :sum, 2000]],
        )
      end

      it { is_expected.to eq(3000) }
    end

    context 'when sensor is :inverter_power_1' do
      let(:sensor) { :inverter_power_1 }

      before do
        create_summary(
          date: Date.new(2025, 1, 1),
          values: [[:inverter_power_1, :sum, 1000]],
        )
        create_summary(
          date: Date.new(2025, 1, 2),
          values: [[:inverter_power_1, :sum, 2000]],
        )
      end

      it { is_expected.to eq(3000) }
    end

    context 'when sensor is :house_power' do
      let(:sensor) { :house_power }

      before do
        create_summary(
          date: Date.new(2025, 1, 1),
          values: [[:house_power, :sum, 7000]],
        )
        create_summary(
          date: Date.new(2025, 1, 2),
          values: [[:house_power, :sum, 6000]],
        )
      end

      it { is_expected.to eq(13_000) }
    end

    context 'when sensor is :custom_power_01' do
      let(:sensor) { :custom_power_01 }

      before do
        create_summary(
          date: Date.new(2025, 1, 1),
          values: [[:custom_power_01, :sum, 500]],
        )
        create_summary(
          date: Date.new(2025, 1, 2),
          values: [[:custom_power_01, :sum, 600]],
        )
      end

      it { is_expected.to eq(1100) }
    end
  end
end
