describe Sensor::Chart::InverterPowerForecast do
  subject(:chart) { described_class.new(timeframe:) }

  let(:timeframe) do
    Timeframe.new("#{Date.current + 1.day}..#{Date.current + 7.days}")
  end

  before do
    freeze_time

    # Create forecast data for 3 days starting tomorrow
    influx_batch do
      # Day 1 (tomorrow) - Complete day with 24 hourly measurements
      # Simple rectangular power profile: 1000W from 8:00-16:00 (8 hours)
      # Expected: 1000W * 8h = 8000 Wh = 8 kWh
      24.times do |hour|
        add_influx_point(
          name: Sensor::Config.measurement(:inverter_power_forecast),
          fields: {
            Sensor::Config.field(:inverter_power_forecast) =>
              forecast_power(hour),
          },
          time: (Date.current + 1.day).beginning_of_day + hour.hours,
        )

        # Add clearsky forecast with doubled power
        add_influx_point(
          name: Sensor::Config.measurement(:inverter_power_forecast_clearsky),
          fields: {
            Sensor::Config.field(:inverter_power_forecast_clearsky) =>
              forecast_power(hour) * 2, # Clearsky = 2x normal = 16 kWh
          },
          time: (Date.current + 1.day).beginning_of_day + hour.hours,
        )
      end

      # Day 2 - Complete day with same pattern (8 kWh)
      24.times do |hour|
        add_influx_point(
          name: Sensor::Config.measurement(:inverter_power_forecast),
          fields: {
            Sensor::Config.field(:inverter_power_forecast) =>
              forecast_power(hour),
          },
          time: (Date.current + 2.days).beginning_of_day + hour.hours,
        )
      end

      # Day 3 - Incomplete day (only 10 hours, should be filtered out)
      10.times do |hour|
        add_influx_point(
          name: Sensor::Config.measurement(:inverter_power_forecast),
          fields: {
            Sensor::Config.field(:inverter_power_forecast) =>
              forecast_power(hour),
          },
          time: (Date.current + 3.days).beginning_of_day + hour.hours,
        )
      end
    end
  end

  # Simple rectangular power curve for easy integration testing
  # Returns 1000W between 8:00 and 16:00 (8 hours), 0W otherwise
  # Integral: 1000W * 8h = 8000 Wh = 8 kWh
  def forecast_power(hour)
    (8...16).cover?(hour) ? 1000 : 0
  end

  describe '#actual_days' do
    it 'returns number of complete forecast days' do
      # Only 2 complete days (day 1 and 2), day 3 is incomplete
      expect(chart.actual_days).to eq(2)
    end
  end

  describe 'incomplete day filtering' do
    it 'excludes days with less than 20 hours of data' do
      # Day 3 has only 10 hours, should be filtered
      expect(chart.actual_days).to eq(2)
    end
  end

  describe 'energy integration' do
    it 'correctly calculates daily kWh using rectangular rule integration' do
      labels = chart.options[:plugins][:customXAxisLabels][:labels]

      # We have 2 complete days, each should have 8 kWh
      # (1000W * 8 hours = 8000 Wh = 8 kWh)
      expect(labels.length).to eq(2)

      # Day 1 should have 8 kWh
      day1_kwh_label =
        labels[0][:lines].find { |line| line[:text].to_s.match?(/^\d+$/) }
      expect(day1_kwh_label[:text].to_i).to eq(8)

      # Day 2 should also have 8 kWh
      day2_kwh_label =
        labels[1][:lines].find { |line| line[:text].to_s.match?(/^\d+$/) }
      expect(day2_kwh_label[:text].to_i).to eq(8)
    end
  end

  describe 'clearsky forecast' do
    before { stub_feature(:inverter_power_forecast_clearsky) }

    it 'includes clearsky forecast in chart sensors' do
      expect(chart.chart_sensor_names).to include(
        :inverter_power_forecast_clearsky,
      )
    end
  end
end
