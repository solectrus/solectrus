describe Sensor::Chart::InverterPowerForecast do
  let(:timeframe) { Timeframe.new("#{Date.current}..#{Date.current + 7.days}") }
  let(:chart) { described_class.new(timeframe: timeframe) }

  describe '#type' do
    it 'returns line chart type' do
      expect(chart.type).to eq('line')
    end
  end

  describe '#use_sql_for_timeframe?' do
    it 'always returns false for InfluxDB usage' do
      expect(chart.use_sql_for_timeframe?).to be false
    end
  end

  describe '#chart_sensor_names' do
    it 'returns configured power sensor names' do
      allow(Sensor::Config).to receive(:sensors).and_return(
        [
          double(name: :inverter_power),
          double(name: :inverter_power_forecast),
          double(name: :inverter_power_forecast_clearsky),
          double(name: :other_sensor),
        ],
      )

      expect(chart.chart_sensor_names).to contain_exactly(
        :inverter_power,
        :inverter_power_forecast,
        :inverter_power_forecast_clearsky,
      )
    end
  end

  describe '#actual_days' do
    before { allow(chart).to receive(:forecast_data).and_return(forecast_data) }

    context 'with 3 days of data' do
      let(:forecast_data) do
        {
          Date.current => {
            total_wh: 10,
          },
          Date.current + 1.day => {
            total_wh: 12,
          },
          Date.current + 2.days => {
            total_wh: 11,
          },
        }
      end

      it 'returns the number of forecast days' do
        expect(chart.actual_days).to eq(3)
      end
    end

    context 'with more than 14 days of data' do
      let(:forecast_data) do
        (0..20).to_h { |i| [Date.current + i.days, { total_wh: 10 }] }
      end

      it 'clamps to maximum of 14 days' do
        expect(chart.actual_days).to eq(14)
      end
    end

    context 'with no data' do
      let(:forecast_data) { {} }

      it 'returns minimum of 1 day' do
        expect(chart.actual_days).to eq(1)
      end
    end
  end
end
