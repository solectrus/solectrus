describe Calculator::Range do
  let(:calculator) do
    described_class.new(
      timeframe,
      calculations: [
        Queries::Calculation.new(:house_power, :sum, :sum),
        Queries::Calculation.new(:house_power_grid, :sum, :sum),
      ],
    )
  end

  let(:timeframe) { Timeframe.day }
  let(:updated_at) { 5.minutes.ago }

  before do
    Price.electricity.create! starts_at: '2020-02-01', value: 0.2545
    Price.electricity.create! starts_at: '2022-02-01', value: 0.3244
    Price.electricity.create! starts_at: '2022-07-01', value: 0.2801
    Price.electricity.create! starts_at: '2023-02-01', value: 0.4451

    Price.feed_in.create! starts_at: '2020-12-01', value: 0.0848

    allow(calculator).to receive_messages(
      inverter_power: 48_000,
      inverter_power_1: 46_000,
      inverter_power_2: 2_000,
      inverter_power_forecast: 50_000,
      got: 1,
      paid: -6,
      traditional_price: -15,
      battery_savings: 3,
      time: updated_at,
    )

    allow(Setting).to receive(:opportunity_costs).and_return(true)
  end

  it 'calculates inverter_power' do
    expect(calculator.inverter_power).to eq(48_000)
  end

  it 'calculates' do
    expect(calculator.forecast_deviation).to eq(-4)
    expect(calculator.solar_price).to eq(-5)
    expect(calculator.savings).to eq(10)
    expect(calculator.battery_savings_percent).to eq(30)

    expect(calculator.time).to eq(updated_at)
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
        #
        custom_power_01: 1_000,
        custom_power_01_array: [1_000],
        custom_power_01_grid: 410,
        custom_power_01_grid_array: [410],
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
      expect(calculator.heatpump_costs).to eq(0.79485)

      expect(calculator.house_power_without_custom_grid_ratio).to eq(51)

      expect(calculator.custom_power_01_grid_ratio).to eq(41)
      expect(calculator.custom_01_costs_pv).to eq(0.050032) # 0.0848 * (1 - 0.410)
      expect(calculator.custom_01_costs_grid).to eq(0.182491) # 0.4451 * 0.410
      expect(calculator.custom_01_costs).to eq(0.232523)
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

      expect(calculator.house_power_without_custom_grid_ratio).to be_nil
    end
  end

  context 'when power-splitter values are missing' do
    let(:timeframe) { Timeframe.new('2024-03-07') }

    before do
      allow(calculator).to receive_messages(
        grid_import_power_array: [0],
        #
        house_power: 1000,
        house_power_array: [1000],
        #
        heatpump_power: 2000,
        heatpump_power_array: [2000],
        #
        wallbox_power: 5000,
        wallbox_power_array: [5000],
      )
    end

    it 'calculates' do
      expect(calculator.wallbox_power).to eq(5000)
      expect(calculator.wallbox_power_grid_ratio).to be_nil
      expect(calculator.wallbox_power_pv_ratio).to be_nil
      expect(calculator.wallbox_costs).to be_nil

      expect(calculator.house_power).to eq(1000)
      expect(calculator.house_power_grid_ratio).to be_nil
      expect(calculator.house_power_pv_ratio).to be_nil
      expect(calculator.house_costs).to be_nil

      expect(calculator.heatpump_power).to eq(2000)
      expect(calculator.heatpump_power_grid_ratio).to be_nil
      expect(calculator.heatpump_power_pv_ratio).to be_nil
      expect(calculator.heatpump_costs).to be_nil

      expect(calculator.house_power_without_custom_grid_ratio).to be_nil
    end
  end

  context 'when power-splitter values are missing, but there is just a single consumer' do
    let(:timeframe) { Timeframe.new('2024-03-07') }

    before do
      allow(calculator).to receive_messages(
        house_power: 1000,
        house_power_array: [1000],
        grid_import_power: 1000,
        grid_import_power_array: [1000],
      )

      allow(SensorConfig).to receive(:x).and_return(
        double(single_consumer?: true),
      )
    end

    it 'calculates' do
      expect(calculator.house_power).to eq(1000)
      expect(calculator.house_costs).to eq(6)
    end
  end
end
