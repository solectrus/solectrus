describe Insights do
  subject(:insights) { described_class.new(sensor:, timeframe:) }

  let(:timeframe) { Timeframe.new('2025-01') }

  describe '#value' do
    subject { insights.value }

    context 'when sensor is :inverter_power' do
      let(:sensor) { Sensor::Registry[:inverter_power] }

      before do
        create_summary(
          date: Date.new(2025, 1, 1),
          values: [
            [:inverter_power, :sum, 1000],
            [:inverter_power_1, :sum, 1000],
          ],
        )
        create_summary(
          date: Date.new(2025, 1, 2),
          values: [
            [:inverter_power, :sum, 2000],
            [:inverter_power_1, :sum, 2000],
          ],
        )
      end

      it { is_expected.to eq(3000) }
    end

    context 'when sensor is :inverter_power_1' do
      let(:sensor) { Sensor::Registry[:inverter_power_1] }

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
      let(:sensor) { Sensor::Registry[:house_power] }

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
      let(:sensor) { Sensor::Registry[:custom_power_01] }

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

    context 'when sensor is :grid_power (calculated from dependencies)' do
      let(:sensor) { Sensor::Registry[:grid_power] }

      before do
        create_summary(
          date: Date.new(2025, 1, 1),
          values: [
            [:grid_export_power, :sum, 8000],
            [:grid_import_power, :sum, 3000],
          ],
        )
        create_summary(
          date: Date.new(2025, 1, 2),
          values: [
            [:grid_export_power, :sum, 6000],
            [:grid_import_power, :sum, 2000],
          ],
        )
      end

      # grid_power = export - import
      # Day 1: 8000 - 3000 = 5000
      # Day 2: 6000 - 2000 = 4000
      # Total: 9000
      it { is_expected.to eq(9000) }

      describe 'trends' do
        it 'yearly_trend is available' do
          expect(insights.yearly_trend).to be_a(Trend)
        end

        it 'monthly_trend is available' do
          expect(insights.monthly_trend).to be_a(Trend)
        end
      end
    end

    context 'when sensor is :heatpump_cop (uses avg aggregation)' do
      let(:sensor) { Sensor::Registry[:heatpump_cop] }

      before do
        stub_feature(:heatpump)

        create_summary(
          date: Date.new(2025, 1, 1),
          values: [
            [:heatpump_power, :sum, 1000],
            [:heatpump_heating_power, :sum, 4000],
          ],
        )
        create_summary(
          date: Date.new(2025, 1, 2),
          values: [
            [:heatpump_power, :sum, 1000],
            [:heatpump_heating_power, :sum, 2000],
          ],
        )
      end

      # COP Day 1: 4000/1000 = 4.0
      # COP Day 2: 2000/1000 = 2.0
      # Average: (4.0 + 2.0) / 2 = 3.0
      it { is_expected.to eq(3.0) }
    end
  end
end
