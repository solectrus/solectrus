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
      allow(calculator).to receive(:inverter_power).and_return(476_000)

      allow(calculator).to receive(:grid_power_plus).and_return(171_000)
      allow(calculator).to receive(:grid_power_plus_array).and_return([171_000])

      allow(calculator).to receive(:grid_power_minus).and_return(129_000)
      allow(calculator).to receive(:grid_power_minus_array).and_return(
        [129_000],
      )

      allow(calculator).to receive(:wallbox_charge_power).and_return(221_000)
      allow(calculator).to receive(:wallbox_charge_power_array).and_return(
        [221_000],
      )

      allow(calculator).to receive(:house_power).and_return(322_000)
      allow(calculator).to receive(:house_power_array).and_return([322_000])

      allow(calculator).to receive(:bat_power_minus).and_return(168_000)
      allow(calculator).to receive(:bat_power_minus_array).and_return([168_000])

      allow(calculator).to receive(:bat_power_plus).and_return(159_000)
      allow(calculator).to receive(:bat_power_plus_array).and_return([159_000])
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
      allow(calculator).to receive(:inverter_power).and_return(205_974)

      allow(calculator).to receive(:grid_power_plus).and_return(360_277)
      allow(calculator).to receive(:grid_power_plus_array).and_return([360_277])

      allow(calculator).to receive(:grid_power_minus).and_return(21_630)
      allow(calculator).to receive(:grid_power_minus_array).and_return([21_630])

      allow(calculator).to receive(:wallbox_charge_power).and_return(187_342)
      allow(calculator).to receive(:wallbox_charge_power_array).and_return(
        [187_342],
      )

      allow(calculator).to receive(:house_power).and_return(360_272)
      allow(calculator).to receive(:house_power_array).and_return([360_272])

      allow(calculator).to receive(:bat_power_minus).and_return(78_916)
      allow(calculator).to receive(:bat_power_minus_array).and_return([78_916])

      allow(calculator).to receive(:bat_power_plus).and_return(75_918)
      allow(calculator).to receive(:bat_power_plus_array).and_return([75_918])
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
      allow(calculator).to receive(:inverter_power).and_return(1_465)

      allow(calculator).to receive(:grid_power_plus).and_return(56_483)
      allow(calculator).to receive(:grid_power_plus_array).and_return([56_483])

      allow(calculator).to receive(:grid_power_minus).and_return(11)
      allow(calculator).to receive(:grid_power_minus_array).and_return([11])

      allow(calculator).to receive(:wallbox_charge_power).and_return(39_802)
      allow(calculator).to receive(:wallbox_charge_power_array).and_return(
        [39_802],
      )

      allow(calculator).to receive(:house_power).and_return(17_026)
      allow(calculator).to receive(:house_power_array).and_return([17_026])

      allow(calculator).to receive(:bat_power_minus).and_return(319)
      allow(calculator).to receive(:bat_power_minus_array).and_return([319])

      allow(calculator).to receive(:bat_power_plus).and_return(1_425)
      allow(calculator).to receive(:bat_power_plus_array).and_return([1_425])
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
      allow(calculator).to receive(:inverter_power).and_return(1_500_000)

      allow(calculator).to receive(:grid_power_plus).and_return(12_816)
      allow(calculator).to receive(:grid_power_plus_array).and_return([12_816])

      allow(calculator).to receive(:grid_power_minus).and_return(1_000_000)
      allow(calculator).to receive(:grid_power_minus_array).and_return(
        [1_000_000],
      )

      allow(calculator).to receive(:wallbox_charge_power).and_return(121_000)
      allow(calculator).to receive(:wallbox_charge_power_array).and_return(
        [121_000],
      )

      allow(calculator).to receive(:house_power).and_return(343_000)
      allow(calculator).to receive(:house_power_array).and_return([343_000])

      allow(calculator).to receive(:bat_power_minus).and_return(117_000)
      allow(calculator).to receive(:bat_power_minus_array).and_return([117_000])

      allow(calculator).to receive(:bat_power_plus).and_return(112_000)
      allow(calculator).to receive(:bat_power_plus_array).and_return([112_000])
    end

    it 'calculates' do
      expect(calculator.forecast_deviation).to be_nil

      expect(calculator.wallbox_costs).to eq(-3.59)
      expect(calculator.house_costs).to eq(0)
      expect(calculator.paid).to eq(-3.59)
    end
  end
end
