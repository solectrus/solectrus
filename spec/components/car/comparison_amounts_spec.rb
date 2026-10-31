describe Car::ComparisonAmounts do
  subject(:amounts) { described_class.new(comparison) }

  def source(cost) = Car::EnergySources::Source.new(energy_wh: 1000.0, cost:)

  let(:comparison) do
    instance_double(
      Car::Comparison,
      sources: { pv: source(629.6), grid: source(1238.6), offsite: source(507.4) },
      sources_without_pv: { grid: source(3578.6), offsite: source(507.4) },
      cost: 2375.6,
      cost_without_pv: 4086.0,
      payment_costs: { 'ghg_quota' => -919.8, 'insurance' => 5300.6 },
      fuel_cost: 9460.4,
      tax: 1345.4,
      car_cost: 6756.4,
      combustion_cost: 16_106.4,
    )
  end

  before { allow(comparison).to receive(:per_100km) { |value| value * 100.0 / 65_047 } }

  # 629.6 + 1238.6 + 507.4 is 2375.6, so the parts add up to 2376: the grid
  # takes the rest
  it 'rounds the costs of the sources to the rounded cost of the energy' do
    expect(amounts.source_costs).to eq(pv: 630, grid: 1239, offsite: 507)
    expect(amounts.energy_cost).to eq(2376)
    expect(amounts.energy_cost_without_pv).to eq(4086)
  end

  # 0.4 + 36.3 + 6.7 is 43.4 and 36.5 + 6.7 is 43.2. If the offsite cost took
  # the rest, it would be 7 with PV and 6 without.
  it 'rounds the offsite cost alike in both columns of the car' do
    allow(comparison).to receive_messages(
      sources: { pv: source(0.4), grid: source(36.3), offsite: source(6.7) },
      sources_without_pv: { grid: source(36.5), offsite: source(6.7) },
    )

    expect(amounts.source_costs).to eq(pv: 0, grid: 36, offsite: 7)
    expect(amounts.source_costs_without_pv).to eq(grid: 36, offsite: 7)
  end

  # -919.8 + 5300.6 is 4380.8, so the categories add up to 4381
  it 'rounds the categories of the payments to the rounded payments' do
    expect(amounts.payment_costs).to eq('ghg_quota' => -920, 'insurance' => 5301)
    expect([amounts.payments, amounts.shared_cost]).to eq([4381, 5301])
  end

  # The exact car cost is 6756.4, but its rounded parts add up to 6757
  it 'adds the rounded parts of each column' do
    expect(amounts.car_cost).to eq(6757)
    expect(amounts.car_cost_without_pv).to eq(8467)
    expect(amounts.combustion_cost).to eq(16_106)
  end

  it 'gives the savings as the difference of the rounded totals' do
    expect(amounts.savings).to eq(9349)
    expect(amounts.savings_without_pv).to eq(7639)
  end

  # 16106.4 and 6756.4 EUR for 65,047 km are 24.761 and 10.387 EUR, and
  # their exact difference is 14.374 EUR
  it 'gives the savings per 100 km as the difference of the rounded values' do
    expect(amounts.per_100km(:combustion_cost)).to eq(24.76)
    expect(amounts.per_100km(:car_cost)).to eq(10.39)
    expect(amounts.savings_per_100km).to be_within(0.001).of(14.37)
  end

  context 'without a distance' do
    before { allow(comparison).to receive(:per_100km).and_return(nil) }

    it 'has no savings per 100 km' do
      expect(amounts.savings_per_100km).to be_nil
    end
  end
end
