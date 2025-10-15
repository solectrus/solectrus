describe Sensor::Registry do
  describe '.all' do
    subject(:list) { described_class.all }

    it 'returns all sensor instances' do
      expect(list).to be_an(Array)
      expect(list).to all(be_a(Sensor::Definitions::Base))
    end
  end

  describe '.[]' do
    subject(:find) { described_class[sensor_name] }

    context 'with known sensor' do
      let(:sensor_name) { :inverter_power }

      it 'returns sensor instance' do
        expect(find).to be_a(Sensor::Definitions::InverterPower)
      end
    end

    context 'with unknown sensor' do
      let(:sensor_name) { :unknown_sensor }

      it 'raises ArgumentError' do
        expect { find }.to raise_error(
          ArgumentError,
          'Unknown sensor: unknown_sensor',
        )
      end
    end

    context 'with non-symbol input' do
      let(:sensor_name) { 'inverter_power' }

      it 'raises ArgumentError' do
        expect { find }.to raise_error(ArgumentError)
      end
    end
  end

  describe '.find' do
    subject(:find) { described_class.find(sensor_name) }

    context 'with known sensor' do
      let(:sensor_name) { :inverter_power }

      it 'returns sensor instance' do
        expect(find).to be_a(Sensor::Definitions::InverterPower)
      end
    end

    context 'with unknown sensor' do
      let(:sensor_name) { :unknown_sensor }

      it 'returns nil' do
        expect(find).to be_nil
      end
    end

    context 'with non-symbol input' do
      let(:sensor_name) { 'inverter_power' }

      it 'raises ArgumentError' do
        expect { find }.to raise_error(
          ArgumentError,
          /Sensor name must be a symbol/,
        )
      end
    end
  end

  describe '.by_category' do
    subject(:by_category) { described_class.by_category(category) }

    context 'with inverter category' do
      let(:category) { :inverter }

      it 'returns inverter sensors only' do
        expect(by_category).to all(have_attributes(category: :inverter))
        expect(by_category.map(&:name)).to include(
          :inverter_power,
          :inverter_power_1,
          :inverter_power_2,
          :inverter_power_3,
          :inverter_power_4,
          :inverter_power_5,
        )
      end
    end

    context 'with consumer category' do
      let(:category) { :consumer }

      it 'returns consumer sensors only' do
        expect(by_category).to all(have_attributes(category: :consumer))
        expect(by_category.map(&:name)).to include(
          :house_power,
          :custom_power_01,
        )
      end
    end

    context 'with unknown category' do
      let(:category) { :unknown_category }

      it 'raises ArgumentError' do
        expect { by_category }.to raise_error(
          ArgumentError,
          'Unknown category: unknown_category',
        )
      end
    end

    context 'with non-symbol category' do
      let(:category) { 'inverter' }

      it 'raises ArgumentError' do
        expect { by_category }.to raise_error(ArgumentError)
      end
    end
  end
end
