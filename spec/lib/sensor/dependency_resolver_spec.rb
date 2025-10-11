describe Sensor::DependencyResolver do
  subject(:resolver) { described_class.new(sensor_names) }

  describe 'initialization' do
    context 'with valid symbols' do
      let(:sensor_names) { %i[inverter_power house_power] }

      it 'is accepted' do
        expect { resolver }.not_to raise_error
        expect(resolver.sensor_names).to eq(%i[inverter_power house_power])
      end
    end
  end

  describe '#resolve' do
    subject(:resolve) { resolver.resolve }

    context 'when single sensor without dependencies' do
      let(:sensor_names) { [:grid_export_power] }

      it 'returns the sensor' do
        expect(resolve).to contain_exactly(:grid_export_power)
      end
    end

    context 'when multiple sensors without dependencies' do
      let(:sensor_names) { %i[grid_export_power case_temp] }

      it 'returns the sensors' do
        expect(resolve).to contain_exactly(:grid_export_power, :case_temp)
      end
    end

    context 'when single sensor with dependency' do
      let(:sensor_names) { [:house_power] }

      it 'returns the sensor and its dependencies' do
        expect(resolve).to contain_exactly(:house_power, :heatpump_power)
      end
    end

    context 'when calculated sensor with multiple dependencies' do
      let(:sensor_names) { [:total_consumption] }

      it 'returns the sensor and its dependencies' do
        expect(resolve).to contain_exactly(
          :total_consumption,
          :house_power,
          :heatpump_power,
          :wallbox_power,
        )
      end
    end

    context 'when calculated sensor with nested dependencies' do
      let(:sensor_names) { [:autarky] }

      it 'returns the sensor and its dependencies' do
        expect(resolve).to contain_exactly(
          :autarky,
          :grid_import_power,
          :house_power,
          :heatpump_power,
          :wallbox_power,
          :total_consumption,
        )
      end
    end

    context 'when unknown sensor' do
      let(:sensor_names) { [:unknown_sensor] }

      it 'raises an ArgumentError' do
        expect { resolve }.to raise_error(ArgumentError)
      end
    end

    context 'when sensor with complex nested dependencies requiring topological order' do
      let(:sensor_names) { [:self_consumption_quote] }

      it 'returns dependencies in correct topological order' do
        # self_consumption_quote depends on [:self_consumption, :inverter_power]
        # self_consumption depends on [:inverter_power, :grid_export_power]
        # inverter_power depends on configured inverter sensors
        # Deterministic alphabetical order within topological constraints
        expect(resolve).to eq(
          %i[
            grid_export_power
            inverter_power_1
            inverter_power_2
            inverter_power_total
            inverter_power
            self_consumption
            self_consumption_quote
          ],
        )
      end
    end

    context 'when multiple sensors with overlapping dependencies' do
      let(:sensor_names) { %i[self_consumption self_consumption_quote] }

      it 'returns dependencies in correct topological order without duplicates' do
        # Both sensors share some dependencies, but should only appear once
        # in the correct topological order
        # Deterministic alphabetical order within topological constraints
        expect(resolve).to eq(
          %i[
            grid_export_power
            inverter_power_1
            inverter_power_2
            inverter_power_total
            inverter_power
            self_consumption
            self_consumption_quote
          ],
        )
      end
    end
  end
end
