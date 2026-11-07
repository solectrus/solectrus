describe Heatpump::ComparisonAmounts do
  subject(:amounts) { described_class.new(comparison) }

  let(:comparison) do
    instance_double(
      Heatpump::Comparison,
      cost: 812.3,
      cost_without_pv: 1490.6,
      payment_costs: { 'maintenance' => 0.4, 'other_expense' => 0.4 },
      fuel_cost: 2104.7,
      fixed_cost: 120.2,
      total_cost: 813.1,
      total_cost_without_pv: 1491.4,
      heating_cost: 2224.9,
    )
  end

  # 0.4 + 0.4 is 0.8, so the categories add up to 1 in whole units, and no
  # category drops out
  it 'rounds the categories of the payments to the rounded payments' do
    expect(amounts.precision).to eq(0)
    expect(amounts.payment_costs).to eq('maintenance' => 0, 'other_expense' => 1)
    expect(amounts.payments).to eq(1)
  end

  it 'adds the rounded parts of each column' do
    expect([amounts.heatpump_cost, amounts.without_pv_cost, amounts.heating_cost]).to eq([813, 1492, 2225])
    expect(amounts.savings).to eq(1412)
  end

  context 'without payments' do
    before { allow(comparison).to receive(:payment_costs).and_return({}) }

    it { expect(amounts.payments).to eq(0) }
  end
end
