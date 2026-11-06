describe Sensor::Query::Helpers::Influx::DslBuilder do
  let(:builder) { described_class.new }

  describe '#min' do
    it 'adds a min request with min as base aggregation' do
      builder.min :battery_soc

      expect(builder.sensor_requests).to eq([%i[battery_soc min min]])
    end

    it 'takes an explicit base aggregation' do
      builder.min :battery_soc, :avg

      expect(builder.sensor_requests).to eq([%i[battery_soc min avg]])
    end
  end

  describe '#max' do
    it 'adds a max request with max as base aggregation' do
      builder.max :battery_soc

      expect(builder.sensor_requests).to eq([%i[battery_soc max max]])
    end

    it 'rejects a sensor that does not allow it' do
      expect { builder.max :grid_costs }.to raise_error(
        ArgumentError,
        "Sensor grid_costs doesn't support aggregation max. Allowed: sum",
      )
    end
  end
end
