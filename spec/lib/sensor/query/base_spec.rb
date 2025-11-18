describe Sensor::Query::Base do
  subject(:query) { described_class.new(sensor_names, timeframe) }

  let(:timeframe) { Timeframe.day }

  describe 'sensor name validation' do
    context 'when all sensor names are valid' do
      let(:sensor_names) { [:house_power] }

      it { expect { query }.not_to raise_error }
    end

    context 'when sensor names are empty' do
      let(:sensor_names) { [] }

      it do
        expect { query }.to raise_error(
          ArgumentError,
          'Sensor names cannot be empty',
        )
      end
    end

    context 'when sensor names are not symbols' do
      let(:sensor_names) { ['house_power', :inverter_power, 123] }

      it do
        expect { query }.to raise_error(
          ArgumentError,
          /Sensor name must be a symbol/,
        )
      end
    end

    context 'with configured sensor' do
      let(:sensor_names) { [:inverter_power] }

      it 'does not raise error' do
        expect { query }.not_to raise_error
      end
    end

    context 'with unconfigured sensor' do
      let(:sensor_names) { [:inverter_power_5] }

      it 'does not raise error' do
        expect { query }.not_to raise_error
      end
    end

    context 'with mixed configured and unconfigured sensors' do
      let(:sensor_names) { %i[inverter_power_1 inverter_power_5] }

      it 'does not raise error' do
        expect { query }.not_to raise_error
      end
    end

    context 'with unknown sensor' do
      let(:sensor_names) { [:completely_unknown_sensor] }

      it 'raises ArgumentError for unknown sensor' do
        expect { query }.to raise_error(
          ArgumentError,
          /Unknown sensor: completely_unknown_sensor/,
        )
      end
    end
  end
end
