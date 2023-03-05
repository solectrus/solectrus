describe Calculator::Range do
  let(:calculator) { described_class.new(timeframe) }

  before do
    Price.electricity.create! starts_at: timeframe.beginning, value: 0.3244
    Price.feed_in.create! starts_at: timeframe.beginning, value: 0.0848
  end

  context 'when grid_power_plus < wallbox_charge_power (November)' do
    let(:timeframe) { Timeframe.new('2022-11') }

    before do
      allow(calculator).to receive(:inverter_power).and_return(476_000)
      allow(calculator).to receive(:watt).and_return(457_000)

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
      expect(calculator.forecast_deviation).to eq(4)

      expect(calculator.paid).to eq(-55.47)
      expect(calculator.got).to eq(10.94)

      expect(calculator.solar_price).to eq(-44.53)
      expect(calculator.traditional_price).to eq(-176.15)

      expect(calculator.savings).to eq(131.62)
      expect(calculator.battery_savings).to eq(41.02)
      expect(calculator.battery_savings_percent).to eq(31)

      expect(calculator.wallbox_costs).to eq(-59.71)
      expect(calculator.house_costs).to eq(-27.31)
      expect(calculator.total_costs).to eq(-87.02)
    end
  end

  context 'when grid_power_plus is very high (December 2021)' do
    let(:timeframe) { Timeframe.new('2021-12') }

    before do
      allow(calculator).to receive(:inverter_power).and_return(206_000)

      allow(calculator).to receive(:grid_power_plus).and_return(360_000)
      allow(calculator).to receive(:grid_power_plus_array).and_return([360_000])

      allow(calculator).to receive(:grid_power_minus).and_return(21_630)
      allow(calculator).to receive(:grid_power_minus_array).and_return([21_630])

      allow(calculator).to receive(:wallbox_charge_power).and_return(187_000)
      allow(calculator).to receive(:wallbox_charge_power_array).and_return(
        [187_000],
      )

      allow(calculator).to receive(:house_power).and_return(360_000)
      allow(calculator).to receive(:house_power_array).and_return([360_000])

      allow(calculator).to receive(:bat_power_minus).and_return(78_916)
      allow(calculator).to receive(:bat_power_minus_array).and_return([78_916])

      allow(calculator).to receive(:bat_power_plus).and_return(75_918)
      allow(calculator).to receive(:bat_power_plus_array).and_return([75_918])
    end

    it 'calculates' do
      expect(calculator.wallbox_costs).to eq(-60.66)
      expect(calculator.house_costs).to eq(-56.12)
      expect(calculator.total_costs).to eq(-116.78)
    end
  end

  context 'when grid_power_plus is very low (August 2022)' do
    let(:timeframe) { Timeframe.new('2022-08') }

    before do
      allow(calculator).to receive(:inverter_power).and_return(1_500_000)
      allow(calculator).to receive(:watt).and_return(1_570_000)

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
      expect(calculator.forecast_deviation).to eq(-4)

      expect(calculator.wallbox_costs).to eq(-13.33)
      expect(calculator.house_costs).to eq(-29.09)
      expect(calculator.total_costs).to eq(-42.42)
    end
  end
end
