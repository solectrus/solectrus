describe Sensor::Chart::InverterPower do
  describe '#inverter_power' do
    let(:chart) { described_class.new(timeframe:) }

    context 'when timeframe is day' do
      let(:timeframe) { Timeframe.new('2025-03-03') }

      it 'calculates energy using integration (Power × Time)' do
        # Simulate hourly power data: 1000 W for 1h + 2000 W for 1h = 3000 Wh
        series = Sensor::Data::Series.new(
          {
            %i[inverter_power avg avg] => {
              Time.zone.local(2025, 3, 3, 10, 0, 0) => 1000,
              Time.zone.local(2025, 3, 3, 11, 0, 0) => 2000,
              Time.zone.local(2025, 3, 3, 12, 0, 0) => 3000,
            },
          },
          timeframe: timeframe,
        )

        allow(chart).to receive(:series).and_return(series)

        # EnergyCalculator: 1000 W * 1h + 2000 W * 1h = 3000 Wh
        expect(chart.inverter_power).to eq(3000.0)
      end
    end

    context 'when timeframe is now' do
      let(:timeframe) { Timeframe.now }

      it 'calculates energy using integration (Power × Time)' do
        now = Time.current
        # Simulate 5-minute interval data: 1200 W for 5 min = 100 Wh
        series = Sensor::Data::Series.new(
          {
            %i[inverter_power avg avg] => {
              now => 1200,
              now + 5.minutes => 1200,
            },
          },
          timeframe: timeframe,
        )

        allow(chart).to receive(:series).and_return(series)

        # EnergyCalculator: 1200 W for 5 minutes = 100 Wh
        expect(chart.inverter_power).to eq(100.0)
      end
    end
  end
end
