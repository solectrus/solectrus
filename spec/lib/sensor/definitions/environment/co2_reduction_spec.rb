Sensor::Registry[:co2_reduction]

describe Sensor::Definitions::Co2Reduction do # rubocop:disable RSpec/SpecFilePathFormat
  subject(:sensor) { described_class.new }

  describe '#calculate' do
    let(:data) { Sensor::Data::Single.new(raw_data, timeframe: Timeframe.day) }

    context 'with inverter power data' do
      let(:raw_data) { { inverter_power: 2500 } }

      it 'calculates CO2 reduction in grams' do
        # 2500W = 2.5kW, CO2 factor = 0.401 kg/kWh => 2.5 * 0.401 * 1000 = 1002.5 grams
        expect(sensor.calculate(**raw_data)).to eq(1003)
      end
    end

    context 'with no inverter power data' do
      let(:raw_data) { { inverter_power: nil } }

      it 'returns nil' do
        expect(sensor.calculate(**raw_data)).to be_nil
      end
    end
  end

  describe 'SQL integration' do
    subject(:result) { query.call }

    describe 'for sum of single day' do
      let(:query) do
        Sensor::Query::Sql.new do |q|
          q.sum :co2_reduction
          q.timeframe Timeframe.new('2024-06-15')
        end
      end

      context 'when inverter_power is present' do
        before do
          # Create data for inverter_power_1 (first dependency when inverter_power is calculated)
          create_summary(
            date: '2024-06-15',
            values: [[:inverter_power_1, :sum, 16_000]],
          )
        end

        it 'return calculation' do
          expect(result.co2_reduction).to eq(16_000 * 0.401)
        end
      end
    end

    describe 'for meta-aggregation' do
      let(:query) do
        Sensor::Query::Sql.new do |q|
          q.sum :co2_reduction, :sum
          q.timeframe Timeframe.new('2024-06')
        end
      end

      context 'when inverter_power is present' do
        before do
          # Create data for inverter_power_1 (first dependency when inverter_power is calculated)
          create_summary(
            date: '2024-06-15',
            values: [[:inverter_power_1, :sum, 16_000]],
          )

          create_summary(
            date: '2024-06-16',
            values: [[:inverter_power_1, :sum, 8_000]],
          )
        end

        it 'returns calculation' do
          expect(result.co2_reduction).to eq(24_000 * 0.401)
        end
      end
    end

    describe 'Forbidden aggregations' do
      %i[avg min max].each do |agg|
        context "when #{agg} of single day" do
          it 'raises ArgumentError during query initialization' do
            expect do
              Sensor::Query::Sql.new do |q|
                q.public_send(agg, :co2_reduction)
                q.timeframe Timeframe.new('2024-06-15')
              end
            end.to raise_error(ArgumentError)
          end
        end
      end
    end
  end
end
