describe Sensor do
  describe '.data?' do
    subject(:data?) { described_class.data? }

    context 'when InfluxDB has data' do
      before do
        add_influx_point(
          name: 'my-pv',
          fields: { inverter_power: 1000.0 },
          time: 1.minute.ago,
        )
      end

      it { is_expected.to be true }
    end

    context 'when InfluxDB is empty' do
      it { is_expected.to be false }
    end
  end
end
