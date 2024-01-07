describe Calculator::Now do
  let(:calculator) { described_class.new }

  describe '#time' do
    around { |example| freeze_time(&example) }

    before do
      add_influx_point(
        name: Rails.configuration.x.influx.measurement_pv,
        fields: {
          inverter_power: 10,
        },
      )
    end

    it 'returns time of measurement' do
      expect(calculator.time).to eq(Time.current)
    end

    it 'returns existing value as float' do
      expect(calculator.inverter_power).to eq(10.0)
    end

    it 'returns missing value as 0' do
      expect(calculator.wallbox_charge_power).to eq(0)
    end
  end
end
