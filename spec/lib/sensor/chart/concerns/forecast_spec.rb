describe Sensor::Chart::Concerns::Forecast do
  subject(:chart) { IncompleteForecastChart.new(timeframe: Timeframe.new('P7D')) }

  before do
    stub_const(
      'IncompleteForecastChart',
      Class.new(Sensor::Chart::Base) { include Sensor::Chart::Concerns::Forecast },
    )
  end

  describe 'template methods' do
    it 'requires #forecast_sensor_name' do
      expect { chart.__send__(:forecast_sensor_name) }.to raise_error(
        NotImplementedError,
        'IncompleteForecastChart must implement #forecast_sensor_name',
      )
    end

    it 'requires #build_day_aggregation' do
      expect { chart.__send__(:build_day_aggregation, Date.current, []) }.to raise_error(
        NotImplementedError,
        'IncompleteForecastChart must implement #build_day_aggregation',
      )
    end
  end
end
