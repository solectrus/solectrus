describe Sensor::Definitions::InverterPowerTotal do # rubocop:disable RSpec/SpecFilePathFormat
  subject(:sensor) { described_class.new }

  before do
    Sensor::Config.setup(
      ENV.to_h.merge(
        'INFLUX_SENSOR_INVERTER_POWER' => '',
        'INFLUX_SENSOR_INVERTER_POWER_1' => 'my-pv:inverter_power',
        'INFLUX_SENSOR_INVERTER_POWER_2' => 'balcony:inverter_power',
      ),
    )
  end

  describe '#calculate' do
    # A roof and a balcony inverter, the setup of issue #5857. `with_data`
    # names the sensors the query result carries; nil stands for a caller that
    # does not know (the summary builder).
    def total(roof, balcony, with_data: %i[inverter_power_1 inverter_power_2])
      sensor.calculate(
        inverter_power_1: roof,
        inverter_power_2: balcony,
        sensor_names_with_data: with_data,
      )
    end

    context 'when the query names the sensors it carries data for' do
      it 'sums the inverters that report' do
        expect(total(1800.0, 107.0)).to eq(1907.0)
      end

      it 'returns nil when one of them misses a bucket (issue #5857)' do
        expect(total(nil, 107.0)).to be_nil
      end

      it 'returns nil when none of them reports' do
        expect(total(nil, nil)).to be_nil
      end

      it 'leaves out an inverter that carries no data in this timeframe' do
        expect(total(1800.0, nil, with_data: %i[inverter_power_1])).to eq(1800.0)
      end

      it 'returns nil when no inverter carries data at all' do
        expect(total(nil, nil, with_data: [])).to be_nil
      end
    end

    context 'without that list (summary building)' do
      it 'sums the inverters that report' do
        expect(total(1800.0, 107.0, with_data: nil)).to eq(1907.0)
      end

      it 'falls back to the lenient reading and sums what it has' do
        expect(total(1800.0, nil, with_data: nil)).to eq(1800.0)
      end

      it 'returns nil when both are missing' do
        expect(total(nil, nil, with_data: nil)).to be_nil
      end
    end
  end
end
