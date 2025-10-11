describe Sensor::Query::PowerPeak do
  subject(:power_peak) { described_class.new(sensor_names, timeframe:) }

  before do
    stub_feature(:multi_inverter)
  end

  describe '#call' do
    subject { power_peak.call }

    let(:start) { 20.days.ago }
    let(:timeframe) { Timeframe.new('P20D') }

    context 'when no sensors are provided' do
      let(:sensor_names) { [] }

      it 'raises an ArgumentError' do
        expect { power_peak.call }.to raise_error(
          ArgumentError,
          'Sensor names cannot be empty',
        )
      end
    end

    context 'when multiple sensors are provided' do
      let(:sensor_names) do
        %i[inverter_power_1 inverter_power_2 heatpump_power]
      end

      context 'when no summaries exist' do
        it { is_expected.to be_nil }
      end

      context 'when summaries are present' do
        before do
          create_summary(
            date: start,
            values: [
              [:inverter_power_1, :max, 1000],
              [:inverter_power_2, :max, 1100],
              [:heatpump_power, :max, 2000],
            ],
          )

          create_summary(
            date: start + 1.day,
            values: [
              [:inverter_power_1, :max, 1500],
              [:inverter_power_2, :max, 1600],
              [:heatpump_power, :max, 2500],
            ],
          )
        end

        it 'returns the maximum value if all sensors' do
          is_expected.to eq(
            inverter_power: 3100,
            inverter_power_1: 1500,
            inverter_power_2: 1600,
            heatpump_power: 2500,
          )
        end
      end
    end

    context 'when one sensor is provided' do
      let(:sensor_names) { %i[inverter_power_1] }

      context 'when no summaries exist' do
        it { is_expected.to be_nil }
      end

      context 'when summaries are present' do
        before do
          create_summary(date: start, values: [[:inverter_power_1, :max, 1000]])

          create_summary(
            date: start + 1.day,
            values: [[:inverter_power_1, :max, 1500]],
          )
        end

        it 'returns the maximum value for this sensor' do
          is_expected.to eq(inverter_power_1: 1500, inverter_power: 1500)
        end
      end
    end

    context 'when multi_inverter without_total' do
      let(:sensor_names) { %i[inverter_power_1 inverter_power_2] }

      it { expect(Sensor::Config).to be_multi_inverter }

      context 'when no summaries exist' do
        it { is_expected.to be_nil }
      end

      context 'when summaries are present' do
        before do
          create_summary(
            date: start,
            values: [
              [:inverter_power_1, :max, 1000],
              [:inverter_power_2, :max, 2000],
            ],
          )

          create_summary(
            date: start + 1.day,
            values: [
              [:inverter_power_1, :max, 1500],
              [:inverter_power_2, :max, 2500],
            ],
          )
        end

        it 'returns the maximum with total' do
          is_expected.to eq(
            inverter_power: 4000,
            inverter_power_1: 1500,
            inverter_power_2: 2500,
          )
        end
      end
    end
  end
end
