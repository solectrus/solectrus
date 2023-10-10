describe Calculator::Now do
  let(:calculator) { described_class.new }

  describe '#time' do
    around { |example| freeze_time(&example) }

    before do
      add_influx_point(
        name: Rails.configuration.x.influx.measurement_pv,
        fields: {
          inverter_power: 0,
        },
      )
    end

    it 'returns time of measurement' do
      expect(calculator.time).to eq(Time.current)
    end
  end
end
