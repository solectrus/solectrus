describe Sensor::Query::Influx::Aggregation do
  subject(:aggregation) { described_class.new(sensor_names, timeframe) }

  describe 'timeframe validation' do
    let(:sensor_names) { [:inverter_power] }

    context 'when timeframe is now' do
      let(:timeframe) { Timeframe.now }

      it 'raises ArgumentError' do
        expect { aggregation }.to raise_error(ArgumentError)
      end
    end

    context 'when timeframe has beginning and ending' do
      let(:timeframe) { Timeframe.day }

      it 'does not raise error' do
        expect { aggregation }.not_to raise_error
      end
    end
  end

  describe '#call' do
    subject(:call) { aggregation.call }

    before do
      freeze_time

      # Setup test data - 6 points spanning 3 hours ago to 30 min ago
      # P2H (last 2 hours) should include 4 points: from 2h ago to 30min ago
      influx_batch do
        [3.0, 2.5, 2.0, 1.5, 1.0, 0.5].each_with_index do |hours_ago, i|
          add_influx_point(
            name: Sensor::Config.measurement(:inverter_power_1),
            fields: {
              Sensor::Config.field(:inverter_power_1) => (i * 100) + 2000, # 2000, 2100, 2200, 2300, 2400, 2500,
              Sensor::Config.field(:grid_import_power) => (i * 50) + 1500, # 1500, 1550, 1600, 1650, 1700, 1750,
            },
            time: hours_ago.hours.ago,
          )

          add_influx_point(
            name: Sensor::Config.measurement(:inverter_power_2),
            fields: {
              Sensor::Config.field(:inverter_power_2) => (i * 25) + 300, # 300, 325, 350, 375, 400, 425
            },
            time: hours_ago.hours.ago,
          )
        end
      end
    end

    context 'when in the last 2 hours' do
      let(:timeframe) { Timeframe.new('P2H') }

      context 'with single sensor' do
        let(:sensor_names) { [:inverter_power_1] }

        it 'calculates aggregations' do
          expect(call).to be_a(Sensor::Data::Base)

          # P2H actually includes values: 2200, 2300, 2400, 2500 (from 2h ago to 30min ago)
          expect(call.inverter_power_1(:min)).to eq(2200.0)
          expect(call.inverter_power_1(:max)).to eq(2500.0)
          expect(call.inverter_power_1(:avg)).to eq(2350.0)
        end
      end

      context 'with multiple sensors from same measurement' do
        let(:sensor_names) { %i[inverter_power_1 grid_import_power] }

        it 'calculates aggregations' do
          expect(call).to be_a(Sensor::Data::Base)

          # P2H inverter_power_1: 2200, 2300, 2400, 2500 (min: 2200, max: 2500, avg: 2350)
          expect(call.inverter_power_1(:min)).to eq(2200.0)
          expect(call.inverter_power_1(:max)).to eq(2500.0)
          expect(call.inverter_power_1(:avg)).to eq(2350.0)

          # P2H grid_import_power: 1600, 1650, 1700, 1750 (min: 1600, max: 1750, avg: 1675)
          expect(call.grid_import_power(:min)).to eq(1600.0)
          expect(call.grid_import_power(:max)).to eq(1750.0)
          expect(call.grid_import_power(:avg)).to eq(1675.0)
        end
      end

      context 'with sensors from different measurements' do
        let(:sensor_names) { %i[inverter_power_1 inverter_power_2] }

        it 'calculates aggregations from different measurements' do
          expect(call).to be_a(Sensor::Data::Base)

          # P2H inverter_power_1: 2200, 2300, 2400, 2500 (min: 2200, max: 2500, avg: 2350)
          expect(call.inverter_power_1(:min)).to eq(2200.0)
          expect(call.inverter_power_1(:max)).to eq(2500.0)
          expect(call.inverter_power_1(:avg)).to eq(2350.0)

          # P2H inverter_power_2: 350, 375, 400, 425 (min: 350, max: 425, avg: 387.5)
          expect(call.inverter_power_2(:min)).to eq(350.0)
          expect(call.inverter_power_2(:max)).to eq(425.0)
          expect(call.inverter_power_2(:avg)).to eq(387.5)
        end
      end
    end

    context 'with no data in timeframe' do
      let(:timeframe) { Timeframe.new('P6D') }
      let(:sensor_names) { [:inverter_power_1] }

      it 'returns empty result when no data exists' do
        expect(call).to be_a(Sensor::Data::Base)
        expect(call.inverter_power_1(:min)).to be_nil
        expect(call.inverter_power_1(:max)).to be_nil
        expect(call.inverter_power_1(:avg)).to be_nil
      end
    end
  end
end
