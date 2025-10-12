Sensor::Registry[:inverter_power]

describe Sensor::Definitions::InverterPower do # rubocop:disable RSpec/SpecFilePathFormat
  subject(:sensor) { described_class.new }

  describe '#calculated?' do
    context 'when inverter_power ENV variable is defined' do
      before do
        Sensor::Config.setup(
          ENV.to_h.merge(
            'INFLUX_SENSOR_INVERTER_POWER' => 'my-pv:total_inverter_power',
          ),
        )
      end

      it 'returns false' do
        expect(sensor.calculated?).to be(false)
      end
    end

    context 'when inverter_power ENV variable is not defined' do
      before do
        Sensor::Config.setup(
          ENV.to_h.merge(
            'INFLUX_SENSOR_INVERTER_POWER' => '',
            'INFLUX_SENSOR_INVERTER_POWER_1' => 'my-pv:inverter_power_1',
            'INFLUX_SENSOR_INVERTER_POWER_2' => 'my-pv:inverter_power_2',
          ),
        )
      end

      it 'returns true' do
        expect(sensor.calculated?).to be(true)
      end

      it 'has inverter_power_total as dependency' do
        expect(sensor.dependencies).to eq([:inverter_power_total])
      end
    end
  end

  describe '#summary_aggregations' do
    context 'when inverter_power is configured (not calculated)' do
      before do
        Sensor::Config.setup(
          ENV.to_h.merge(
            'INFLUX_SENSOR_INVERTER_POWER' => 'my-pv:total_inverter_power',
          ),
        )
      end

      it 'returns [:sum, :max] to enable storing in summary table' do
        expect(sensor.summary_aggregations).to eq(%i[sum max])
      end

      it 'is included in SummaryValue field enum' do
        expect(SummaryValue.fields.keys).to include('inverter_power')
      end
    end

    context 'when inverter_power is not configured (calculated from parts)' do
      before do
        Sensor::Config.setup(
          ENV.to_h.merge(
            'INFLUX_SENSOR_INVERTER_POWER' => '',
            'INFLUX_SENSOR_INVERTER_POWER_1' => 'my-pv:inverter_power_1',
            'INFLUX_SENSOR_INVERTER_POWER_2' => 'my-pv:inverter_power_2',
          ),
        )
      end

      it 'returns [:sum, :max] to enable storing calculated values in summary table' do
        expect(sensor.summary_aggregations).to eq(%i[sum max])
      end

      it 'is included in SummaryValue field enum' do
        expect(SummaryValue.fields.keys).to include('inverter_power')
      end
    end
  end

  describe '#calculate' do
    subject do
      sensor.calculate(
        inverter_power: raw_data[:inverter_power],
        inverter_power_total: raw_data[:inverter_power_total],
      )
    end

    context 'with full data' do
      let(:raw_data) { { inverter_power: 1000, inverter_power_total: 800 } }

      it { is_expected.to eq(1000) }
    end

    context 'with inverter_power only' do
      let(:raw_data) { { inverter_power: 1750, inverter_power_total: nil } }

      it { is_expected.to eq(1750) }
    end

    context 'with inverter_power_total only' do
      let(:raw_data) { { inverter_power: nil, inverter_power_total: 800 } }

      it { is_expected.to eq(800) }
    end

    context 'with no data' do
      let(:raw_data) { { inverter_power: nil, inverter_power_total: nil } }

      it { is_expected.to be_nil }
    end
  end

  describe 'SQL integration' do
    subject(:result) { query.call }

    context 'when inverter_power is defined (not calculated)' do
      before do
        Sensor::Config.setup(
          ENV.to_h.merge(
            'INFLUX_SENSOR_INVERTER_POWER' => 'my-pv:total_inverter_power',
          ),
        )
      end

      describe 'for sum of single day' do
        let(:query) do
          Sensor::Query::Sql.new do |q|
            q.sum :inverter_power, :sum
            q.timeframe Timeframe.new('2024-06-15')
          end
        end

        context 'when all is present' do
          before do
            create_summary(
              date: '2024-06-15',
              values: [
                [:inverter_power, :sum, 16_000],
                [:inverter_power_1, :sum, 10_000],
                [:inverter_power_2, :sum, 5_000],
              ],
            )
          end

          it 'return total' do
            expect(result.inverter_power(:sum, :sum)).to eq(16_000)
          end
        end

        context 'when total only' do
          before do
            create_summary(
              date: '2024-06-15',
              values: [[:inverter_power, :sum, 25_000]],
            )
          end

          it 'returns total' do
            expect(result.inverter_power(:sum, :sum)).to eq(25_000)
          end
        end

        context 'when parts only' do
          before do
            create_summary(
              date: '2024-06-15',
              values: [
                [:inverter_power_1, :sum, 10_000],
                [:inverter_power_2, :sum, 5_000],
              ],
            )
          end

          it 'returns nil (no total configured)' do
            expect(result.inverter_power(:sum, :sum)).to be_nil
          end
        end
      end

      describe 'for sum of sums of a month' do
        let(:query) do
          Sensor::Query::Sql.new do |q|
            q.sum :inverter_power, :sum
            q.timeframe Timeframe.new('2024-06')
          end
        end

        context 'when all is present' do
          before do
            create_summary(
              date: '2024-06-15',
              values: [
                [:inverter_power, :sum, 16_000],
                [:inverter_power_1, :sum, 10_000],
                [:inverter_power_2, :sum, 5_000],
              ],
            )

            create_summary(
              date: '2024-06-16',
              values: [
                [:inverter_power, :sum, 8_000],
                [:inverter_power_1, :sum, 5_000],
                [:inverter_power_2, :sum, 2_500],
              ],
            )
          end

          it 'returns total' do
            expect(result.inverter_power(:sum, :sum)).to eq(24_000)
          end
        end

        context 'when total only' do
          before do
            create_summary(
              date: '2024-06-15',
              values: [[:inverter_power, :sum, 25_000]],
            )

            create_summary(
              date: '2024-06-16',
              values: [[:inverter_power, :sum, 10_000]],
            )
          end

          it 'returns total' do
            expect(result.inverter_power(:sum, :sum)).to eq(35_000)
          end
        end

        context 'when parts only' do
          before do
            create_summary(
              date: '2024-06-15',
              values: [
                [:inverter_power_1, :sum, 10_000],
                [:inverter_power_2, :sum, 5_000],
              ],
            )

            create_summary(
              date: '2024-06-16',
              values: [
                [:inverter_power_1, :sum, 8_000],
                [:inverter_power_2, :sum, 4_000],
              ],
            )
          end

          it 'returns nil (no total configured)' do
            expect(result.inverter_power(:sum, :sum)).to be_nil
          end
        end
      end
    end

    context 'when inverter_power is not defined (calculated)' do
      before do
        Sensor::Config.setup(
          ENV.to_h.merge(
            'INFLUX_SENSOR_INVERTER_POWER' => '',
            'INFLUX_SENSOR_INVERTER_POWER_1' => 'my-pv:inverter_power_1',
            'INFLUX_SENSOR_INVERTER_POWER_2' => 'my-pv:inverter_power_2',
          ),
        )
      end

      describe 'for sum of single day (calculated from parts)' do
        let(:query) do
          Sensor::Query::Sql.new do |q|
            q.sum :inverter_power, :sum
            q.timeframe Timeframe.new('2024-06-15')
          end
        end

        context 'when calculated from parts' do
          before do
            create_summary(
              date: '2024-06-15',
              values: [
                [:inverter_power, :sum, 15_000], # Calculated and stored value
                [:inverter_power_1, :sum, 10_000], # Parts also stored
                [:inverter_power_2, :sum, 5_000],
              ],
            )
          end

          it 'returns stored calculated value from summary' do
            expect(result.inverter_power).to eq(15_000)
          end
        end

        context 'when no parts are present' do
          it 'returns nil' do
            expect(result.inverter_power).to be_nil
          end
        end
      end
    end
  end
end
