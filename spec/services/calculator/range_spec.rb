describe Calculator::Range do
  let(:calculator) { described_class.new(timeframe) }

  before do
    Price.electricity.create! starts_at: '2020-02-01', value: 0.2545
    Price.electricity.create! starts_at: '2022-02-01', value: 0.3244
    Price.electricity.create! starts_at: '2022-07-01', value: 0.2801
    Price.electricity.create! starts_at: '2023-02-01', value: 0.4451

    Price.feed_in.create! starts_at: '2020-12-01', value: 0.0848
  end

  context 'when grid_import_power < wallbox_power (November)' do
    let(:timeframe) { Timeframe.new('2022-11') }

    before do
      allow(calculator).to receive_messages(
        inverter_power: 476_000,
        grid_import_power: 171_000,
        grid_import_power_array: [171_000],
        grid_export_power: 129_000,
        grid_export_power_array: [129_000],
        wallbox_power: 221_000,
        wallbox_power_array: [221_000],
        house_power: 322_000,
        house_power_array: [322_000],
        battery_discharging_power: 168_000,
        battery_discharging_power_array: [168_000],
        battery_charging_power: 159_000,
        battery_charging_power_array: [159_000],
      )
    end

    it 'calculates' do
      expect(calculator.forecast_deviation).to be_nil

      expect(calculator.paid).to eq(-47.90)
      expect(calculator.got).to eq(10.94)

      expect(calculator.solar_price).to eq(-36.96)
      expect(calculator.traditional_price).to eq(-152.09)

      expect(calculator.savings).to eq(115.13)
      expect(calculator.battery_savings).to eq(33.57)
      expect(calculator.battery_savings_percent).to eq(29)

      expect(calculator.paid).to eq(-47.90)
    end
  end

  context 'when grid_import_power is very high (December 2021)' do
    let(:timeframe) { Timeframe.new('2021-12') }

    before do
      allow(calculator).to receive_messages(
        inverter_power: 205_974,
        grid_import_power: 360_277,
        grid_import_power_array: [360_277],
        grid_export_power: 21_630,
        grid_export_power_array: [21_630],
        wallbox_power: 187_342,
        wallbox_power_array: [187_342],
        house_power: 360_272,
        house_power_array: [360_272],
        battery_discharging_power: 78_916,
        battery_discharging_power_array: [78_916],
        battery_charging_power: 75_918,
        battery_charging_power_array: [75_918],
      )
    end

    it 'calculates' do
      expect(calculator.paid).to eq(-91.69)
    end
  end

  context 'when grid_import_power is at maximum (2021-12-25)' do
    let(:timeframe) { Timeframe.new('2021-12-25') }

    before do
      allow(calculator).to receive_messages(
        inverter_power: 1_465,
        grid_import_power: 56_483,
        grid_import_power_array: [56_483],
        grid_export_power: 11,
        grid_export_power_array: [11],
        wallbox_power: 39_802,
        wallbox_power_array: [39_802],
        house_power: 17_026,
        house_power_array: [17_026],
        battery_discharging_power: 319,
        battery_discharging_power_array: [319],
        battery_charging_power: 1_425,
        battery_charging_power_array: [1_425],
      )
    end

    it 'calculates' do
      expect(calculator.paid).to eq(-14.37)
    end
  end

  context 'when grid_import_power is very low (August 2022)' do
    let(:timeframe) { Timeframe.new('2022-08') }

    before do
      allow(calculator).to receive_messages(
        inverter_power: 1_500_000,
        grid_import_power: 12_816,
        grid_import_power_array: [12_816],
        grid_export_power: 1_000_000,
        grid_export_power_array: [1_000_000],
        wallbox_power: 121_000,
        wallbox_power_array: [121_000],
        house_power: 343_000,
        house_power_array: [343_000],
        battery_discharging_power: 117_000,
        battery_discharging_power_array: [117_000],
        battery_charging_power: 112_000,
        battery_charging_power_array: [112_000],
      )
    end

    it 'calculates' do
      expect(calculator.forecast_deviation).to be_nil

      expect(calculator.paid).to eq(-3.59)
    end
  end

  context 'when power-splitter values are present' do
    let(:timeframe) { Timeframe.new('2024-03-07') }

    before do
      allow(calculator).to receive_messages(
        grid_import_power_array: [3000],
        #
        house_power: 10_000,
        house_power_array: [10_000],
        house_power_grid: 5000,
        house_power_grid_array: [5000],
        #
        heatpump_power: 3000,
        heatpump_power_array: [3000],
        heatpump_power_grid: 1500,
        heatpump_power_grid_array: [1500],
        #
        wallbox_power: 20_000,
        wallbox_power_array: [20_000],
        wallbox_power_grid: 10_000,
        wallbox_power_grid_array: [10_000],
      )
    end

    it 'calculates' do
      expect(calculator.wallbox_power_grid_ratio).to eq(50)
      expect(calculator.wallbox_power_pv_ratio).to eq(50)
      expect(calculator.wallbox_costs).to eq(5.299)

      expect(calculator.house_power_grid_ratio).to eq(50)
      expect(calculator.house_power_pv_ratio).to eq(50)
      expect(calculator.house_costs).to eq(2.6495)

      expect(calculator.heatpump_power_grid_ratio).to eq(50)
      expect(calculator.heatpump_power_pv_ratio).to eq(50)
      expect(calculator.heatpump_costs).to eq(0.5299)
    end
  end

  context 'when power-splitter values are present, but zero' do
    let(:timeframe) { Timeframe.new('2024-03-07') }

    before do
      allow(calculator).to receive_messages(
        grid_import_power_array: [0],
        #
        house_power: 0,
        house_power_array: [0],
        house_power_grid: 0,
        house_power_grid_array: [0],
        #
        heatpump_power: 0,
        heatpump_power_array: [0],
        heatpump_power_grid: 0,
        heatpump_power_grid_array: [0],
        #
        wallbox_power: 0,
        wallbox_power_array: [0],
        wallbox_power_grid: 0,
        wallbox_power_grid_array: [0],
      )
    end

    it 'calculates' do
      expect(calculator.wallbox_power_grid_ratio).to eq(0)
      expect(calculator.wallbox_power_pv_ratio).to eq(100)
      expect(calculator.wallbox_costs).to eq(0)

      expect(calculator.house_power_grid_ratio).to eq(0)
      expect(calculator.house_power_pv_ratio).to eq(100)
      expect(calculator.house_costs).to eq(0)

      expect(calculator.heatpump_power_grid_ratio).to eq(0)
      expect(calculator.heatpump_power_pv_ratio).to eq(100)
      expect(calculator.heatpump_costs).to eq(0)
    end
  end
end
