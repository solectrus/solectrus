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

  describe '#power_ratio_limited?' do
    subject { calculator.power_ratio_limited? }

    context 'when power_ratio is 100' do
      before do
        add_influx_point(
          name: Rails.configuration.x.influx.measurement_pv,
          fields: {
            power_ratio: 100,
          },
        )
      end

      it { is_expected.to be(false) }
    end

    context 'when power_ratio is 70' do
      before do
        add_influx_point(
          name: Rails.configuration.x.influx.measurement_pv,
          fields: {
            power_ratio: 70,
          },
        )
      end

      it { is_expected.to be(true) }
    end

    context 'when power_ratio is missing' do
      it { is_expected.to be(false) }
    end
  end
end
