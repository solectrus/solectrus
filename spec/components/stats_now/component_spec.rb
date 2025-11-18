describe StatsNow::Component, type: :component do
  let(:data) do
    instance_double(
      Sensor::Data::Single,
      sensor_names: %i[inverter_power house_power],
    )
  end
  let(:sensor) { instance_double(Sensor::Definitions::Base) }
  let(:component) { described_class.new(data:, sensor:) }

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
