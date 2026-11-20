describe Car::ChangesOverview do
  subject(:overview) { described_class.new(timeframe: Timeframe.new('2026-01'), base: :previous_year, car: nil) }

  def row(name) = overview.rows.find { it.sensor.name == name }

  before do
    travel_to Date.new(2026, 3, 1)
    stub_feature(:trends, :car)
  end

  it 'groups the charts by the columns of the car page' do
    start = Time.zone.local(2026, 1, 10, 12)
    ChargingSession.create!(kind: :wallbox, origin: :detection, started_at: start, ended_at: start + 1.hour, kwh: 10, cost: 3, car_id: Car.configured.first.id)

    expect(overview.groups.keys).to eq(%i[charging])
    expect(overview.groups[:charging].map { it.sensor.name }).to eq(%i[car_charging car_charging_costs])
  end

  it 'keeps the selection of the car in its links' do
    expect(overview.link_params).to eq(base: nil, car: overview.selection.to_param)
  end

  it 'has no change without a value' do
    expect(overview.rows.map(&:change)).to all(be_nil)
  end

  # Without a session, the charging has no costs in either period
  it 'leaves out a chart without a value in either period' do
    expect(row(:car_charging_costs)).to be_nil
  end
end
