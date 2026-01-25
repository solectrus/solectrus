describe Sensor::Chart::InverterPower do
  describe '#inverter_power' do
    let(:chart) { described_class.new(timeframe:) }

    context 'when timeframe is week' do
      let(:timeframe) { Timeframe.new('2025-W10') }

      it 'uses aggregations_for_sensor when summing series data' do
        series = Sensor::Data::Series.new(
          {
            %i[inverter_power sum sum] => {
              Date.new(2025, 3, 3) => 1000,
              Date.new(2025, 3, 4) => 2000,
            },
          },
          timeframe: timeframe,
        )

        allow(chart).to receive(:series).and_return(series)

        expect(chart.inverter_power).to eq(3000)
      end
    end

    context 'when timeframe is day' do
      let(:timeframe) { Timeframe.new('2025-03-03') }

      it 'uses influx aggregations when summing series data' do
        series = Sensor::Data::Series.new(
          {
            %i[inverter_power avg avg] => {
              Time.zone.local(2025, 3, 3, 10, 0, 0) => 1.5,
              Time.zone.local(2025, 3, 3, 11, 0, 0) => 2.5,
            },
          },
          timeframe: timeframe,
        )

        allow(chart).to receive(:series).and_return(series)

        expect(chart.inverter_power).to eq(4.0)
      end
    end

    context 'when timeframe is now' do
      let(:timeframe) { Timeframe.now }

      it 'uses influx aggregations when summing series data' do
        now = Time.current
        series = Sensor::Data::Series.new(
          {
            %i[inverter_power avg avg] => {
              now => 1.0,
              now + 5.minutes => 2.0,
            },
          },
          timeframe: timeframe,
        )

        allow(chart).to receive(:series).and_return(series)

        expect(chart.inverter_power).to eq(3.0)
      end
    end
  end
end
