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

  describe '#style_for_sensor' do
    let(:inverter_power_sensor) do
      double(name: :inverter_power, color_hex: '#ff0000')
    end
    let(:forecast_sensor) do
      double(name: :inverter_power_forecast, color_hex: '#00ff00')
    end
    let(:clearsky_sensor) do
      double(name: :inverter_power_forecast_clearsky, color_hex: '#abcdef')
    end

    before do
      allow(chart).to receive(:chart_sensors).and_return(
        [inverter_power_sensor],
      )
    end

    it 'applies fill style for inverter_power sensor' do
      result = chart.__send__(:style_for_sensor, inverter_power_sensor)

      expect(result[:fill]).to be true
    end

    it 'applies dashed style for clearsky forecast sensor' do
      result = chart.__send__(:style_for_sensor, clearsky_sensor)

      expect(result).to include(
        borderWidth: 1,
        borderDash: [2, 3],
        fill: false,
        backgroundColor: '#abcdef',
      )
    end

    it 'applies default style for regular forecast sensor' do
      result = chart.__send__(:style_for_sensor, forecast_sensor)

      # Should call super and return base style
      expect(result).to be_a(Hash)
    end
  end
end
