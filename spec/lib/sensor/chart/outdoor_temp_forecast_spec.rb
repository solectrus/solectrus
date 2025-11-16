describe Sensor::Chart::OutdoorTempForecast do
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
    it 'returns configured temperature sensor names' do
      allow(Sensor::Config).to receive(:sensors).and_return(
        [
          double(name: :outdoor_temp),
          double(name: :outdoor_temp_forecast),
          double(name: :other_sensor),
        ],
      )

      expect(chart.chart_sensor_names).to contain_exactly(
        :outdoor_temp,
        :outdoor_temp_forecast,
      )
    end
  end

  # rubocop:disable RSpec/MultipleMemoizedHelpers
  describe 'Sensor::Forecast::TemperatureAggregator' do
    let(:date) { Date.current }
    let(:forecast_entries) do
      [[1.hour.from_now, 18.5], [2.hours.from_now, 19.2]]
    end
    let(:actual_data) { [[1.hour.ago, 17.0]] }
    let(:forecast_data) { forecast_entries }
    let(:aggregator) do
      Sensor::Forecast::TemperatureAggregator.new(
        date,
        forecast_entries,
        actual_data,
        forecast_data,
      )
    end

    describe '#call' do
      it 'returns hash with noon_timestamp and avg_temp' do
        result = aggregator.call
        expect(result).to have_key(:noon_timestamp)
        expect(result).to have_key(:avg_temp)
      end

      it 'calculates noon timestamp in milliseconds' do
        result = aggregator.call
        expected_noon = (date.to_time + 12.hours).to_i * 1000
        expect(result[:noon_timestamp]).to eq(expected_noon)
      end

      context 'when date is in future' do
        let(:date) { Date.tomorrow }

        it 'calculates average from forecast entries only' do
          result = aggregator.call
          # (18.5 + 19.2) / 2 = 18.85
          expect(result[:avg_temp]).to be_within(0.01).of(18.85)
        end
      end

      context 'when date is today' do
        let(:date) { Date.current }
        let(:actual_data) { [[2.hours.ago, 15.0], [1.hour.ago, 16.0]] }
        let(:forecast_data) do
          [[1.hour.from_now, 18.0], [2.hours.from_now, 20.0]]
        end

        it 'combines actual past temps and forecast future temps' do
          result = aggregator.call
          # (15.0 + 16.0 + 18.0 + 20.0) / 4 = 17.25
          expect(result[:avg_temp]).to be_within(0.01).of(17.25)
        end
      end

      context 'with empty entries' do
        let(:forecast_entries) { [] }
        let(:actual_data) { nil }

        it 'returns nil for avg_temp' do
          result = aggregator.call
          expect(result[:avg_temp]).to be_nil
        end
      end

      context 'with nil temperature values' do
        let(:date) { Date.tomorrow }
        let(:forecast_entries) do
          [[1.hour.from_now, nil], [2.hours.from_now, 20.0]]
        end

        it 'filters out nil values' do
          result = aggregator.call
          expect(result[:avg_temp]).to eq(20.0)
        end
      end
    end
  end
  # rubocop:enable RSpec/MultipleMemoizedHelpers

  describe 'BoundaryAdjuster with edge strategy' do
    let(:boundary_interval) { 15.minutes }

    describe '#call' do
      context 'with future data' do
        let(:future_time) { 1.day.from_now.beginning_of_day + 8.hours }
        let(:series_raw_data) do
          {
            [:outdoor_temp_forecast] => {
              future_time => 5.0,
              future_time + 4.hours => 10.0,
              future_time + 8.hours => 8.0,
            },
          }
        end

        it 'adds boundary before first entry with first value' do
          Sensor::Forecast::BoundaryAdjuster.add_edge_boundaries!(
            series_raw_data,
          )
          boundary_time = future_time - boundary_interval

          expect(
            series_raw_data[[:outdoor_temp_forecast]][boundary_time],
          ).to eq(5.0)
        end

        it 'adds boundary after last entry with last value' do
          Sensor::Forecast::BoundaryAdjuster.add_edge_boundaries!(
            series_raw_data,
          )
          last_time = future_time + 8.hours
          boundary_time = last_time + boundary_interval

          expect(
            series_raw_data[[:outdoor_temp_forecast]][boundary_time],
          ).to eq(8.0)
        end

        it 'preserves existing data' do
          Sensor::Forecast::BoundaryAdjuster.add_edge_boundaries!(
            series_raw_data,
          )

          expect(series_raw_data[[:outdoor_temp_forecast]][future_time]).to eq(
            5.0,
          )
        end

        it 'does not overwrite existing boundaries' do
          boundary_time = future_time - boundary_interval
          series_raw_data[[:outdoor_temp_forecast]][boundary_time] = 99.0

          Sensor::Forecast::BoundaryAdjuster.add_edge_boundaries!(
            series_raw_data,
          )
          expect(
            series_raw_data[[:outdoor_temp_forecast]][boundary_time],
          ).to eq(99.0)
        end
      end

      context 'with past data' do
        let(:past_time) { 1.day.ago.beginning_of_day + 8.hours }
        let(:series_raw_data) do
          {
            [:outdoor_temp_forecast] => {
              past_time => 5.0,
              past_time + 4.hours => 10.0,
              past_time + 8.hours => 8.0,
            },
          }
        end

        it 'skips boundary before first entry (in the past)' do
          Sensor::Forecast::BoundaryAdjuster.add_edge_boundaries!(
            series_raw_data,
          )
          boundary_time = past_time - boundary_interval

          expect(
            series_raw_data[[:outdoor_temp_forecast]][boundary_time],
          ).to be_nil
        end

        it 'still adds boundary after last entry' do
          Sensor::Forecast::BoundaryAdjuster.add_edge_boundaries!(
            series_raw_data,
          )
          last_time = past_time + 8.hours
          boundary_time = last_time + boundary_interval

          expect(
            series_raw_data[[:outdoor_temp_forecast]][boundary_time],
          ).to eq(8.0)
        end
      end

      context 'with empty data' do
        let(:series_raw_data) { { [:outdoor_temp_forecast] => {} } }

        it 'does not add boundaries' do
          Sensor::Forecast::BoundaryAdjuster.add_edge_boundaries!(
            series_raw_data,
          )
          expect(series_raw_data[[:outdoor_temp_forecast]]).to eq({})
        end
      end
    end
  end

  describe '#style_for_sensor' do
    let(:outdoor_temp_sensor) do
      double(name: :outdoor_temp, color_hex: '#ff0000')
    end
    let(:forecast_sensor) do
      double(name: :outdoor_temp_forecast, color_hex: '#00ff00')
    end

    before do
      allow(chart).to receive(:chart_sensors).and_return([outdoor_temp_sensor])
    end

    it 'applies fill style for outdoor_temp sensor' do
      result = chart.__send__(:style_for_sensor, outdoor_temp_sensor)

      expect(result[:fill]).to be true
      expect(result[:borderWidth]).to eq(2)
    end

    it 'applies no-fill style for forecast sensor' do
      result = chart.__send__(:style_for_sensor, forecast_sensor)

      expect(result[:fill]).to be false
      expect(result[:borderWidth]).to eq(2)
    end
  end
end
