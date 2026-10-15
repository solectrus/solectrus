describe Balance::StatsNow::Component, type: :component do
  let(:data) do
    instance_double(
      Sensor::Data::Single,
      sensor_names: %i[inverter_power house_power],
    )
  end
  let(:sensor) { instance_double(Sensor::Definitions::Base) }
  let(:component) { described_class.new(data:, sensor:) }

  describe 'the car' do
    let(:car) { Car.create!(id: 1) }
    let(:data) { Sensor::Data::Single.new(payload, timeframe: Timeframe.now) }
    let(:payload) { { car_battery_soc_1: 78.0, wallbox_car_connected: false } }

    before { allow(Car).to receive(:sole_in_use).and_return(car) }

    it 'reads the state of charge of the one car in use from the data' do
      expect(component.car_soc).to eq(78.0)
    end

    it 'takes the plug of the wallbox' do
      expect(component.car_connected).to be(false)
    end

    context 'without the one car in use' do
      let(:car) { nil }

      it 'has no state of charge' do
        expect(component.car_soc).to be_nil
      end
    end
  end

  describe '#max_flow' do
    context 'when peak data has positive values' do
      before do
        allow(component).to receive(:peak).and_return(
          { inverter_power: 8000, house_power: 3000 },
        )
      end

      it 'returns the maximum peak value' do
        expect(component.max_flow).to eq(8000)
      end
    end

    context 'when peak returns empty hash (no data available)' do
      before { allow(component).to receive(:peak).and_return({}) }

      it 'returns the default value of 5000' do
        expect(component.max_flow).to eq(5000)
      end
    end

    context 'when peak data contains only zeros' do
      before do
        allow(component).to receive(:peak).and_return(
          { inverter_power: 0, house_power: 0 },
        )
      end

      it 'returns the default value of 5000' do
        expect(component.max_flow).to eq(5000)
      end
    end

    context 'when peak data contains only nil values' do
      before do
        allow(component).to receive(:peak).and_return(
          { inverter_power: nil, house_power: nil },
        )
      end

      it 'returns the default value of 5000' do
        expect(component.max_flow).to eq(5000)
      end
    end

    context 'when peak data contains mix of nil, zero, and positive values' do
      before do
        allow(component).to receive(:peak).and_return(
          { inverter_power: 0, house_power: nil, wallbox_power: 4000 },
        )
      end

      it 'returns the maximum positive value' do
        expect(component.max_flow).to eq(4000)
      end
    end

    context 'when peak data contains negative values (edge case)' do
      before do
        allow(component).to receive(:peak).and_return(
          { inverter_power: -100, house_power: 0 },
        )
      end

      it 'returns the default value of 5000' do
        expect(component.max_flow).to eq(5000)
      end
    end
  end
end
