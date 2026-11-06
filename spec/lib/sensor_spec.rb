describe Sensor do
  describe '.data?' do
    subject(:data?) { described_class.data? }

    context 'when InfluxDB is empty' do
      it { is_expected.to be false }
    end

    context 'when InfluxDB has data' do
      before do
        add_influx_point(
          name: 'my-pv',
          fields: { inverter_power: 1000.0 },
          time: 1.minute.ago,
        )
      end

      it { is_expected.to be true }

      context 'with an InfluxDB older than 2.2' do
        before do
          allow(ServiceVersions).to receive(:at_least?).with(:influxdb, '2.2').and_return(false)
          allow(Influx).to receive(:query).and_call_original
        end

        it 'looks back the default window, without a start' do
          expect(data?).to be true
          expect(Influx).to have_received(:query).with(satisfy { it.exclude?('start:') })
        end
      end
    end

    context 'when InfluxDB cannot be queried' do
      before do
        allow(Influx).to receive(:query).and_raise(Influx::QueryError, 'unreachable')
        allow(Rails.logger).to receive(:error)
      end

      it { is_expected.to be false }

      it 'logs the error' do
        data?

        expect(Rails.logger).to have_received(:error).with('Error checking InfluxDB for data: unreachable')
      end
    end
  end
end
