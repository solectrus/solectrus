describe Calculator::Now do
  let(:calculator) { described_class.new }

  describe '#time' do
    around { |example| freeze_time(&example) }

    before do
      add_influx_point(
        name: measurement_inverter_power,
        fields: {
          field_inverter_power => 10,
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
      expect(calculator.wallbox_power).to eq(0)
    end
  end

  describe '#system_status' do
    around { |example| freeze_time(&example) }

    context 'when system_status is present' do
      before do
        add_influx_point(
          name: measurement_inverter_power,
          fields: {
            field_system_status => 'Sleeping',
          },
        )
      end

      it 'returns existing value' do
        expect(calculator.system_status).to eq('Sleeping')
      end
    end

    context 'when system_status has invalid encoding' do
      before do
        add_influx_point(
          name: measurement_inverter_power,
          fields: {
            field_system_status => '🌞'.force_encoding('ASCII-8BIT'),
          },
        )
      end

      it 'returns existing value with fixed encoding' do
        expect(calculator.system_status).to eq('🌞')
      end
    end

    context 'when system_status is missing' do
      it 'returns existing value' do
        expect(calculator.system_status).to be_nil
      end
    end
  end

  describe '#house_power' do
    subject { calculator.house_power }

    context 'when heatpump is on' do
      before do
        add_influx_point(
          name: measurement_house_power,
          fields: {
            field_house_power => 1500,
          },
        )

        add_influx_point(
          name: measurement_heatpump_power,
          fields: {
            field_heatpump_power => 500,
          },
        )
      end

      it { is_expected.to eq(1000) }
    end

    context 'when heatpump is not present' do
      before do
        add_influx_point(
          name: measurement_house_power,
          fields: {
            field_house_power => 1500,
          },
        )
      end

      it { is_expected.to eq(1500) }
    end

    context 'when house_power is zero because of SENEC wallbox (with heatpump)' do
      before do
        add_influx_point(
          name: measurement_house_power,
          fields: {
            field_house_power => 0,
            field_wallbox_power => 5000,
          },
        )

        add_influx_point(
          name: measurement_heatpump_power,
          fields: {
            field_heatpump_power => 500,
          },
        )
      end

      it { is_expected.to eq(0) }
    end

    context 'when house_power is zero because of SENEC wallbox (without heatpump)' do
      before do
        add_influx_point(
          name: measurement_house_power,
          fields: {
            field_house_power => 0,
            field_wallbox_power => 5000,
          },
        )
      end

      it { is_expected.to eq(0) }
    end
  end

  describe '#grid_export_limit_active?' do
    subject { calculator.grid_export_limit_active? }

    context 'when grid_export_limit is 100' do
      before do
        add_influx_point(
          name: measurement_grid_export_limit,
          fields: {
            field_grid_export_limit => 100,
          },
        )
      end

      it { is_expected.to be(false) }
    end

    context 'when grid_export_limit is 70' do
      before do
        add_influx_point(
          name: measurement_grid_export_limit,
          fields: {
            field_grid_export_limit => 70,
          },
        )
      end

      it { is_expected.to be(true) }
    end

    context 'when grid_export_limit is missing' do
      it { is_expected.to be(false) }
    end
  end
end
