describe Sensor::Chart::HeatpumpTankTemp do
  subject(:chart) { described_class.new(timeframe:) }

  before do
    stub_feature(:heatpump)
  end

  context 'with weekly timeframe (SQL path)' do
    let(:timeframe) { Timeframe.new('2025-W10') }

    before do
      create_summary(
        date: '2025-03-03',
        values: [
          [:heatpump_tank_temp, :min, 30],
          [:heatpump_tank_temp, :max, 55],
        ],
      )

      create_summary(
        date: '2025-03-07',
        values: [
          [:heatpump_tank_temp, :min, 28],
          [:heatpump_tank_temp, :max, 52],
        ],
      )
    end

    it 'builds labels for every day' do
      expect(chart.data[:labels].length).to eq(7)
    end

    it 'builds dataset with min/max range data' do
      chart.data[:datasets].tap do |datasets|
        expect(datasets.length).to eq(1)

        datasets.first.tap do |dataset|
          expect(dataset[:id]).to eq(:heatpump_tank_temp)
          expect(dataset[:data]).to include([30, 55])
        end
      end
    end

    it 'excludes setpoint sensor' do
      expect(chart.chart_sensor_names).to eq(%i[heatpump_tank_temp])
    end
  end

  context 'with daily timeframe (InfluxDB path)' do
    let(:timeframe) { Timeframe.new(Date.current.iso8601) }

    it 'includes setpoint sensor' do
      expect(chart.chart_sensor_names).to contain_exactly(
        :heatpump_tank_temp,
        :heatpump_tank_temp_setpoint,
      )
    end
  end
end
