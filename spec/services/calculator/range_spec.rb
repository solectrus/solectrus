describe Calculator::Range do
  let(:calculator) { described_class.new(timeframe) }

  let(:timeframe) { Timeframe.new('2022-11') }

  before do
    Price.electricity.create! starts_at: timeframe.beginning, value: 0.3244
    Price.feed_in.create! starts_at: timeframe.beginning, value: 0.0848

    allow(calculator).to receive(:inverter_power).and_return(476_000)
    allow(calculator).to receive(:watt).and_return(457_000)

    allow(calculator).to receive(:grid_power_plus).and_return(171_000)
    allow(calculator).to receive(:grid_power_plus_array).and_return([171_000])

    allow(calculator).to receive(:grid_power_minus).and_return(129_000)
    allow(calculator).to receive(:grid_power_minus_array).and_return([129_000])

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
    expect(calculator.forecast_quality).to eq(4)

    expect(calculator.paid).to eq(-55.47)
    expect(calculator.got).to eq(10.94)

    expect(calculator.solar_price).to eq(-44.53)
    expect(calculator.traditional_price).to eq(-176.15)

    expect(calculator.savings).to eq(131.62)
    expect(calculator.battery_savings).to eq(41.02)
    expect(calculator.battery_savings_percent).to eq(31)
  end
end
