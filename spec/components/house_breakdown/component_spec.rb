describe HouseBreakdown::Component, type: :component do
  subject(:component) do
    described_class.new(data:, timeframe:, sensor_name: :house_power)
  end

  before do
    stub_feature(:power_splitter, :custom_consumer)

    # Set up config with only one custom power sensor
    env = ENV.to_h.merge('INFLUX_SENSOR_CUSTOM_POWER_01' => 'Consumer-01:power')
    (2..20).each { |i| env["INFLUX_SENSOR_CUSTOM_POWER_#{format('%02d', i)}"] = '' }
    Sensor::Config.setup(env)
  end

  let(:timeframe) { Timeframe.day }
  let(:updated_at) { 3.minutes.ago }

  let(:data) do
    HouseBalance.new(
      Sensor::Data::Single.new(
        {
          house_power: 5000,
          house_power_grid: 2500,
          house_power_without_custom: 3800,
          custom_power_01: 1200,
          custom_power_01_grid: 600,
          custom_power_total: 1200,
          grid_import_power: 100,
          grid_export_power: 200,
          inverter_power: 8000,
          battery_charging_power: 100,
          battery_discharging_power: 50,
          wallbox_power: 500,
          heatpump_power: 300,
        },
        timeframe:,
        time: updated_at,
      ),
    )
  end

  describe '#table_rows' do
    it 'includes sensors with non-zero values' do
      sensors = component.table_rows.map { |r| r[:sensor].name }

      expect(sensors).to include(:custom_power_01)
    end

    it 'sorts by percent descending' do
      percents = component.table_rows.pluck(:percent)

      expect(percents).to eq(percents.sort_by(&:-@))
    end

    it 'excludes sensors with zero value and zero percent' do
      zero_rows = component.table_rows.select { |r| r[:percent].zero? }

      expect(zero_rows).to be_empty
    end
  end

  describe '#sorted_segments' do
    it 'returns sensors sorted by value ascending' do
      segments = component.sorted_segments

      expect(segments).to all(respond_to(:name))
    end
  end

  describe '#other_sensor' do
    it 'returns the house_power_without_custom sensor' do
      expect(component.other_sensor.name).to eq(:house_power_without_custom)
    end
  end

  describe '#other_percent' do
    it 'returns a numeric value' do
      expect(component.other_percent).to be_a(Float)
    end

    it 'calculates percent relative to house_power' do
      expect(component.other_percent).to eq(3800.fdiv(5000) * 100.0)
    end
  end

  describe '#common_scaling' do
    # Thresholds: < 1_000 -> :off, < 1_000_000 -> :kilo, >= 1_000_000 -> :mega
    def data_with(custom_power_01:, house_power_without_custom: 0)
      house_power = custom_power_01 + house_power_without_custom

      HouseBalance.new(
        Sensor::Data::Single.new(
          {
            house_power:,
            house_power_without_custom:,
            custom_power_01:,
            custom_power_total: custom_power_01,
            grid_import_power: 0,
            grid_export_power: 0,
            inverter_power: 0,
            battery_charging_power: 0,
            battery_discharging_power: 0,
            wallbox_power: 0,
            heatpump_power: 0,
          },
          timeframe:,
          time: updated_at,
        ),
      )
    end

    context 'when all values are zero' do
      let(:data) { data_with(custom_power_01: 0) }

      it 'returns :auto' do
        expect(component.common_scaling).to eq(:auto)
      end
    end

    context 'when values are in watt range (< 1_000)' do
      let(:data) { data_with(custom_power_01: 500, house_power_without_custom: 300) }

      it 'returns :off' do
        expect(component.common_scaling).to eq(:off)
      end
    end

    context 'when values are in kilowatt range (1_000..999_999)' do
      let(:data) { data_with(custom_power_01: 5_000, house_power_without_custom: 3_000) }

      it 'returns :kilo' do
        expect(component.common_scaling).to eq(:kilo)
      end
    end

    context 'when values are in megawatt range (>= 1_000_000)' do
      let(:data) { data_with(custom_power_01: 2_000_000, house_power_without_custom: 1_500_000) }

      it 'returns :mega' do
        expect(component.common_scaling).to eq(:mega)
      end
    end
  end

  describe '#sensor_count' do
    it 'returns the number of included custom sensors' do
      expect(component.sensor_count).to eq(1)
    end
  end
end
