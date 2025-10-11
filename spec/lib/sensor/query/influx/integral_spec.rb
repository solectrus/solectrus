describe Sensor::Query::Influx::Integral do
  subject(:integral) { described_class.new(sensor_names, timeframe) }

  describe 'timeframe validation' do
    let(:sensor_names) { [:inverter_power] }

    context 'when timeframe is now' do
      let(:timeframe) { Timeframe.now }

      it 'raises ArgumentError' do
        expect { integral }.to raise_error(ArgumentError)
      end
    end

    context 'when timeframe has beginning and ending' do
      let(:timeframe) { Timeframe.day }

      it 'does not raise error' do
        expect { integral }.not_to raise_error
      end
    end
  end

  describe 'sensor validation' do
    let(:timeframe) { Timeframe.day }

    context 'with watt sensors' do
      let(:sensor_names) { [:inverter_power] }

      it 'does not raise error' do
        expect { integral }.not_to raise_error
      end
    end

    context 'with non-watt sensor' do
      let(:sensor_names) { [:case_temp] }

      it 'raises ArgumentError for celsius sensor' do
        expect { integral }.to raise_error(
          ArgumentError,
          /Invalid sensor name: case_temp. Only sensors with unit :watt allowed/,
        )
      end
    end

    context 'with mixed sensor types' do
      let(:sensor_names) { %i[inverter_power case_temp] }

      it 'raises ArgumentError for non-watt sensor' do
        expect { integral }.to raise_error(
          ArgumentError,
          /Invalid sensor name: case_temp. Only sensors with unit :watt allowed/,
        )
      end
    end

    context 'with multiple watt sensors' do
      let(:sensor_names) { %i[inverter_power house_power] }

      it 'accepts all watt sensors' do
        expect { integral }.not_to raise_error
      end
    end
  end

  describe '#call' do
    subject(:call) { integral.call }

    before do
      freeze_time

      # Setup test data with power values over time for integral calculation
      influx_batch do
        # Create power data over a 2-hour period
        (0..4).each do |hour_offset|
          add_influx_point(
            name: Sensor::Config.measurement(:inverter_power_1), # "my-pv"
            fields: {
              Sensor::Config.field(:inverter_power_1) =>
                (hour_offset * 100) + 2000, # 2000, 2100, 2200, 2300, 2400
              Sensor::Config.field(:house_power) => (hour_offset * 50) + 1500, # 1500, 1550, 1600, 1650, 1700
            },
            time: 2.hours.ago + hour_offset.hours,
          )

          add_influx_point(
            name: Sensor::Config.measurement(:inverter_power_2), # "balcony"
            fields: {
              Sensor::Config.field(:inverter_power_2) =>
                (hour_offset * 25) + 300.0, # 300, 325, 350, 375, 400
            },
            time: 2.hours.ago + hour_offset.hours,
          )
        end
      end
    end

    context 'when in the last 2 hours' do
      let(:timeframe) { Timeframe.new('P2H') }

      context 'with single sensor' do
        let(:sensor_names) { [:inverter_power_1] }

        it 'calculates energy integral from power data' do
          expect(call).to be_a(Sensor::Data::Base)
          expect(call).to be_a(Sensor::Data::Single)
          expect(call.inverter_power_1).to eq(2050.0)
        end
      end

      context 'with multiple sensors from same measurement' do
        let(:sensor_names) { %i[inverter_power_1 house_power] }

        it 'calculates integrals for all sensors' do
          expect(call).to be_a(Sensor::Data::Base)
          expect(call).to be_a(Sensor::Data::Single)
          expect(call.inverter_power_1).to eq(2050.0)
          expect(call.house_power).to eq(1525.0)
        end
      end

      context 'with sensors from different measurements' do
        let(:sensor_names) { %i[inverter_power_1 inverter_power_2] }

        it 'calculates integrals from different measurements' do
          expect(call).to be_a(Sensor::Data::Base)
          expect(call).to be_a(Sensor::Data::Single)
          expect(call.inverter_power_1).to eq(2050.0)
          expect(call.inverter_power_2).to eq(312.5)
        end
      end
    end

    context 'with no data in timeframe' do
      let(:timeframe) { Timeframe.new('P6D') }
      let(:sensor_names) { [:inverter_power_1] }

      it 'returns empty result when no data exists' do
        expect(call).to be_a(Sensor::Data::Base)
        expect(call.inverter_power_1).to be_nil
      end
    end
  end
end
