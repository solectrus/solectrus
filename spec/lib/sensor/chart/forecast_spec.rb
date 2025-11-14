describe Sensor::Chart::Forecast do
  subject(:chart) { described_class.new(timeframe:) }

  let(:timeframe) { Timeframe.new("#{Date.current}..#{Date.current + 7.days}") }

  before do
    # Freeze time at 7:00 AM (before power production starts at 8:00)
    # This ensures all forecast power hours are in the future
    freeze_time(Date.current.beginning_of_day + 7.hours)

    # Create forecast and actual data for testing
    influx_batch do
      # Day 0 (today) - Actual inverter power for the morning (0:00-7:00)
      # This represents real production data up to now (frozen at 7:00 AM)
      # No power yet (production starts at 8:00)
      7.times do |hour|
        add_influx_point(
          name: Sensor::Config.measurement(:inverter_power),
          fields: {
            Sensor::Config.field(:inverter_power) => forecast_power(hour),
          },
          time: Date.current.beginning_of_day + hour.hours,
        )
      end

      # Day 0 (today) - Forecast for the full day (will show future part)
      # 1000W * 8h = 8 kWh total forecast
      24.times do |hour|
        add_influx_point(
          name: Sensor::Config.measurement(:inverter_power_forecast),
          fields: {
            Sensor::Config.field(:inverter_power_forecast) =>
              forecast_power(hour),
          },
          time: Date.current.beginning_of_day + hour.hours,
        )
      end

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
    it 'returns number of days with forecast data' do
      # All 4 days have at least 8 hours of data
      # (Day 0=today, Day 1=tomorrow, Day 2=day after, Day 3=incomplete day with 10 hours)
      expect(chart.actual_days).to eq(4)
    end
  end

  describe 'incomplete day filtering' do
    it 'includes days with at least 8 hours of data' do
      # Day 3 has 10 hours, which meets the 8-hour threshold
      expect(chart.actual_days).to eq(4)
    end
  end

  describe 'energy integration' do
    it 'correctly calculates daily kWh using rectangular rule integration' do
      labels = chart.options[:plugins][:customXAxisLabels][:labels]

      # We have 4 days with data
      # Day 0 (today), Day 1 (tomorrow), Day 2 (day after), Day 3 (incomplete)
      # (1000W * 8 hours = 8000 Wh = 8 kWh for complete days)
      expect(labels.length).to eq(4)

      # Extract kWh values from labels
      # For today, the label shows "Remaining X", for other days just "X"
      kwh_values =
        labels.map do |label|
          line = label[:lines].find { |l| l[:text].to_s.match?(/\d+/) }
          next unless line

          line[:text].scan(/\d+/).first.to_i
        end

      # Day 0 (today): 8 kWh (shown as "Remaining 8")
      # Day 1 (tomorrow): 8 kWh
      # Day 2: 8 kWh
      # Day 3 (incomplete, only 10 hours with 2 hours of power): 2 kWh
      expect(kwh_values).to eq([8, 8, 8, 2])
    end
  end

  describe 'chart sensors' do
    it 'includes actual inverter power for today' do
      expect(chart.chart_sensor_names).to include(:inverter_power)
    end

    it 'includes forecast sensors' do
      expect(chart.chart_sensor_names).to include(
        :inverter_power_forecast,
        :inverter_power_forecast_clearsky,
      )
    end
  end

  describe 'blank handling' do
    context 'when no forecast sensors exist' do
      before do
        allow(Sensor::Config).to receive(:sensors).and_return(
          [Sensor::Registry[:inverter_power]],
        )
      end

      it 'includes only inverter_power' do
        expect(chart.chart_sensor_names).to eq([:inverter_power])
      end

      it 'returns blank chart when no forecast data available' do
        # Chart is blank because there's no forecast data
        expect(chart.blank?).to be(true)
      end

      it 'returns unit from inverter_power sensor' do
        # Unit comes from inverter_power sensor when no forecast sensors exist
        expect(chart.unit).to eq('W')
      end
    end
  end
end
