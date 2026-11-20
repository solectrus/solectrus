describe Car::YearsOverview do
  subject(:overview) { described_class.new(timeframe: Timeframe.all, car: nil) }

  def wallbox(date, kwh:)
    start = date.in_time_zone.change(hour: 12)
    ChargingSession.create!(kind: :wallbox, origin: :detection, started_at: start, ended_at: start + 1.hour, kwh:, cost: kwh * 0.3, car_id: 1)
  end

  def row(name) = overview.rows.find { it.sensor.name == name }

  before do
    travel_to Time.zone.local(2026, 3, 1, 12)
    stub_feature(:trends, :car)
    Car.create!(id: 1, active_from: Date.new(2023, 6, 1))

    wallbox(Date.new(2023, 7, 1), kwh: 10)
    wallbox(Date.new(2024, 7, 1), kwh: 30)
    wallbox(Date.new(2025, 7, 1), kwh: 20)
    wallbox(Date.new(2026, 1, 15), kwh: 5)
  end

  it 'has the value of each year from the year of the first car' do
    expect(row(:car_charging).values).to eq(2023 => 10_000, 2024 => 30_000, 2025 => 20_000, 2026 => 5_000)
  end

  it 'counts the first year of the car and the running year as partial' do
    expect(row(:car_charging).partial_years).to contain_exactly(2023, 2026)
    expect(row(:car_charging).best_year).to eq(2025)
  end

  # Without a day of use and without a guest session, no year counts
  it 'has no years without a car in use' do
    allow(Car::Trend).to receive(:first_day_of_use).and_return(nil)

    expect(overview.rows).to be_empty
  end

  it 'leaves out a chart without a value in any year' do
    expect(row(:car_distance)).to be_nil
  end

  it 'groups the charts by the columns of the car page and keeps the car in its links' do
    expect(overview.groups.keys).to eq(%i[charging])
    expect(overview.link_params).to eq(car: nil)
  end
end
