describe Sensor::Chart::HeatpumpCopScatter do
  subject(:chart) { described_class.new(timeframe:) }

  before { stub_feature(:heatpump) }

  describe 'with week timeframe' do
    let(:timeframe) { Timeframe.new('2025-W10') }

    before do
      # Monday - cold day, COP = 87500 / 25000 = 3.5
      create_summary(
        date: '2025-03-03',
        values: [
          [:heatpump_power, :sum, 25_000],
          [:heatpump_heating_power, :sum, 87_500],
          [:outdoor_temp, :avg, -2.0],
        ],
      )

      # Tuesday - mild day, COP = 63000 / 15000 = 4.2
      create_summary(
        date: '2025-03-04',
        values: [
          [:heatpump_power, :sum, 15_000],
          [:heatpump_heating_power, :sum, 63_000],
          [:outdoor_temp, :avg, 8.0],
        ],
      )

      # Wednesday - no data (gap)

      # Thursday - warm day, COP = 51000 / 10000 = 5.1
      create_summary(
        date: '2025-03-06',
        values: [
          [:heatpump_power, :sum, 10_000],
          [:heatpump_heating_power, :sum, 51_000],
          [:outdoor_temp, :avg, 12.0],
        ],
      )
    end

    it 'returns scatter chart type' do
      expect(chart.type).to eq('scatter')
    end

    it 'has correct chart_sensor_names' do
      expect(chart.chart_sensor_names).to eq(
        %i[heatpump_cop outdoor_temp heatpump_power],
      )
    end

    it 'builds scatter dataset with points' do
      data = chart.data

      expect(data[:datasets].length).to eq(1)
      expect(data[:datasets].first[:id]).to eq('cop_scatter')

      points = data[:datasets].first[:data]
      expect(points.length).to eq(3)

      # Points should have x (temp), y (cop), power, r (radius), timestamp, drilldownPath
      expect(points).to all(
        include(:x, :y, :power, :r, :timestamp, :drilldownPath),
      )
    end

    it 'maps temperature to x and COP to y' do
      points = chart.data[:datasets].first[:data]

      cold_day = points.find { |p| p[:x].negative? }
      expect(cold_day[:y]).to eq(3.5)

      warm_day = points.max_by { |p| p[:x] }
      expect(warm_day[:y]).to eq(5.1)
    end

    it 'includes tooltip fields' do
      dataset = chart.data[:datasets].first

      expect(dataset[:tooltipFields]).to be_an(Array)
      expect(dataset[:tooltipFields].length).to eq(3)
    end
  end

  describe 'with short timeframe (day)' do
    let(:timeframe) { Timeframe.new('2025-03-03') }

    it 'uses InfluxDB for hourly data' do
      # Day view uses InfluxDB with hourly aggregation
      expect(chart.__send__(:use_sql_for_timeframe?)).to be(false)
    end

    it 'returns nil when no InfluxDB data available' do
      # Without InfluxDB data, scatter chart has no points
      expect(chart.data).to be_nil
    end
  end

  describe 'with invalid COP values' do
    let(:timeframe) { Timeframe.new('2025-W10') }

    before do
      # Zero COP (heatpump_power = 0) - should be filtered
      create_summary(
        date: '2025-03-03',
        values: [
          [:heatpump_power, :sum, 0],
          [:heatpump_heating_power, :sum, 0],
          [:outdoor_temp, :avg, 5.0],
        ],
      )

      # COP > 8 (95000/10000 = 9.5) - should be filtered
      create_summary(
        date: '2025-03-04',
        values: [
          [:heatpump_power, :sum, 10_000],
          [:heatpump_heating_power, :sum, 95_000],
          [:outdoor_temp, :avg, 10.0],
        ],
      )

      # Valid COP = 4.0
      create_summary(
        date: '2025-03-05',
        values: [
          [:heatpump_power, :sum, 10_000],
          [:heatpump_heating_power, :sum, 40_000],
          [:outdoor_temp, :avg, 7.0],
        ],
      )
    end

    it 'filters out invalid COP values' do
      points = chart.data[:datasets].first[:data]

      expect(points.length).to eq(1)
      expect(points.first[:y]).to eq(4.0)
    end
  end

  describe 'options' do
    let(:timeframe) { Timeframe.new('2025-W10') }

    it 'configures scatter-specific options' do
      options = chart.options

      expect(options[:scales][:x][:type]).to eq('linear')
      expect(options[:plugins][:legend]).to be(false)
      expect(options[:plugins][:zoom][:zoom][:drag][:enabled]).to be(true)
    end
  end
end
