describe Calculator::Range do
  let(:calculator) { described_class.new(timeframe) }

  before do
    Price.electricity.create! starts_at: '2020-02-01', value: 0.2545
    Price.electricity.create! starts_at: '2022-02-01', value: 0.3244
    Price.electricity.create! starts_at: '2022-07-01', value: 0.2801
    Price.electricity.create! starts_at: '2023-02-01', value: 0.4451

    Price.feed_in.create! starts_at: '2020-12-01', value: 0.0848
  end

  context 'when grid_power_plus < wallbox_charge_power (November)' do
    let(:timeframe) { Timeframe.new('2022-11') }

    before do
      allow(calculator).to receive_messages(
        inverter_power: 476_000,
        grid_power_plus: 171_000,
        grid_power_plus_array: [171_000],
        grid_power_minus: 129_000,
        grid_power_minus_array: [129_000],
        wallbox_charge_power: 221_000,
        wallbox_charge_power_array: [221_000],
        house_power: 322_000,
        house_power_array: [322_000],
        bat_power_minus: 168_000,
        bat_power_minus_array: [168_000],
        bat_power_plus: 159_000,
        bat_power_plus_array: [159_000],
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

      expect(calculator.wallbox_costs).to eq(-47.90)
      expect(calculator.house_costs).to eq(0)
      expect(calculator.paid).to eq(-47.90)
    end
  end

  context 'when grid_power_plus is very high (December 2021)' do
    let(:timeframe) { Timeframe.new('2021-12') }

    before do
      allow(calculator).to receive_messages(
        inverter_power: 205_974,
        grid_power_plus: 360_277,
        grid_power_plus_array: [360_277],
        grid_power_minus: 21_630,
        grid_power_minus_array: [21_630],
        wallbox_charge_power: 187_342,
        wallbox_charge_power_array: [187_342],
        house_power: 360_272,
        house_power_array: [360_272],
        bat_power_minus: 78_916,
        bat_power_minus_array: [78_916],
        bat_power_plus: 75_918,
        bat_power_plus_array: [75_918],
      )
    end

    it 'calculates' do
      expect(calculator.wallbox_costs).to eq(-47.68)
      expect(calculator.house_costs).to eq(-44.01)
      expect(calculator.paid).to eq(-91.69)
    end
  end

  context 'when grid_power_plus is at maximum (2021-12-25)' do
    let(:timeframe) { Timeframe.new('2021-12-25') }

    before do
      allow(calculator).to receive_messages(
        inverter_power: 1_465,
        grid_power_plus: 56_483,
        grid_power_plus_array: [56_483],
        grid_power_minus: 11,
        grid_power_minus_array: [11],
        wallbox_charge_power: 39_802,
        wallbox_charge_power_array: [39_802],
        house_power: 17_026,
        house_power_array: [17_026],
        bat_power_minus: 319,
        bat_power_minus_array: [319],
        bat_power_plus: 1_425,
        bat_power_plus_array: [1_425],
      )
    end

    it 'calculates' do
      expect(calculator.wallbox_costs).to eq(-10.13)
      expect(calculator.house_costs).to eq(-4.25)
      expect(calculator.paid).to eq(-14.37)
    end
  end

  context 'when grid_power_plus is very low (August 2022)' do
    let(:timeframe) { Timeframe.new('2022-08') }

    before do
      allow(calculator).to receive_messages(
        inverter_power: 1_500_000,
        grid_power_plus: 12_816,
        grid_power_plus_array: [12_816],
        grid_power_minus: 1_000_000,
        grid_power_minus_array: [1_000_000],
        wallbox_charge_power: 121_000,
        wallbox_charge_power_array: [121_000],
        house_power: 343_000,
        house_power_array: [343_000],
        bat_power_minus: 117_000,
        bat_power_minus_array: [117_000],
        bat_power_plus: 112_000,
        bat_power_plus_array: [112_000],
      )
    end

    it 'calculates' do
      expect(calculator.forecast_deviation).to be_nil

      expect(calculator.wallbox_costs).to eq(-3.59)
      expect(calculator.house_costs).to eq(0)
      expect(calculator.paid).to eq(-3.59)
    end
  end
end
