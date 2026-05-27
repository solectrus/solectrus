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

  describe '#data' do
    # Forecast data is sampled at 15-min intervals (see Concerns::Forecast).
    # The chart spans 7 days; the actual sensor only has data for today up
    # to "now", matching the real shape on the /forecast page.
    def build_15min_forecast_series
      start = Date.current.beginning_of_day.in_time_zone
      timestamps = Array.new(7 * 24 * 4) { |i| start + (i * 15).minutes }

      forecast = timestamps.to_h do |t|
        hours_from_noon = (t.hour + (t.min / 60.0) - 12).abs
        [t, [8000 - ((hours_from_noon**2) * 100), 0].max]
      end
      clearsky = forecast.transform_values { |v| v * 1.1 }
      now = Time.current
      actual = timestamps.take_while { |t| t <= now }.index_with { 600.0 }

      Sensor::Data::Series.new(
        {
          %i[inverter_power avg avg] => actual,
          %i[inverter_power_forecast avg avg] => forecast,
          %i[inverter_power_forecast_clearsky avg avg] => clearsky,
        },
        timeframe: timeframe,
      )
    end

    before do
      allow(chart).to receive_messages(
        chart_sensor_names: %i[
          inverter_power
          inverter_power_forecast
          inverter_power_forecast_clearsky
        ],
        series: build_15min_forecast_series,
      )
    end

    it 'emits a dataset for each configured sensor' do
      ids = chart.data[:datasets].pluck(:id) # rubocop:disable Rails/PluckId -- not AR
      expect(ids).to contain_exactly(
        'inverter_power',
        'inverter_power_forecast',
        'inverter_power_forecast_clearsky',
      )
    end

    it 'keeps the forecast values on the dataset (not silently dropped)' do
      forecast_dataset =
        chart.data[:datasets].find { |d| d[:id] == 'inverter_power_forecast' }

      expect(forecast_dataset[:data].compact.max).to be > 0
    end

    # Regression for the spanGaps/cadence mismatch: Chart.js' numeric spanGaps
    # with a time scale breaks the line between consecutive non-null points
    # whose X-distance exceeds the value. If spanGaps is smaller than the data
    # cadence (15 min for forecast data), every step of the line is broken
    # and the curve disappears even though the data is present.
    it 'sets spanGaps wide enough to render every step of the data cadence' do
      labels = chart.data[:labels]

      chart.data[:datasets].each do |dataset|
        next unless dataset[:data].is_a?(Array)
        next unless dataset[:spanGaps].is_a?(Numeric)

        nn = dataset[:data].each_index.reject { |i| dataset[:data][i].nil? }
        next if nn.size < 2

        max_step = nn.each_cons(2).map { |a, b| labels[b] - labels[a] }.max
        expect(dataset[:spanGaps]).to be >= max_step,
                                      "#{dataset[:id]} has a #{max_step}ms step between consecutive samples but spanGaps is #{dataset[:spanGaps]}ms -- Chart.js will break the line at every step"
      end
    end
  end
end
