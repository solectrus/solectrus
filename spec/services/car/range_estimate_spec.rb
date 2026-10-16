describe Car::RangeEstimate do
  subject(:estimate) { described_class.new([car]) }

  let(:car) { Car.create!(id: 1, active_from: Date.new(2026, 1, 1)) }
  let(:today) { Date.new(2026, 9, 23) }
  let(:kwh_per_percent) { 0.55 }

  def summary(date, field, aggregation, value)
    Summary.find_or_create_by!(date:)
    SummaryValue.create!(date:, field:, aggregation:, value:)
  end

  def charge(date, kwh)
    start = date.in_time_zone.change(hour: 12)
    ChargingSession.create!(kind: :wallbox, origin: :detection, car:, started_at: start, ended_at: start + 1.hour, kwh:, kwh_grid: kwh)
  end

  before do
    travel_to today.in_time_zone.change(hour: 12)
    allow(ChargingSession).to receive(:kwh_per_percent).and_return(car.id => kwh_per_percent)

    # 200 km and 40 kWh in the window: 20 kWh per 100 km
    summary(Date.new(2026, 9, 15), :car_odometer_1, :sum, 200)
    charge(Date.new(2026, 9, 16), 40)
  end

  # 0.55 kWh of a percentage point at 0.2 kWh per km
  it 'gives the distance of a percentage point' do
    expect(estimate.km_per_percent(car)).to be_within(0.001).of(2.75)
  end

  it 'counts no driving before the window' do
    summary(Date.new(2026, 9, 8), :car_odometer_1, :sum, 300)

    expect(estimate.km_per_percent(car)).to be_within(0.001).of(2.75)
  end

  context 'without enough sessions' do
    let(:kwh_per_percent) { nil }

    it { expect(estimate.km_per_percent(car)).to be_nil }
  end

  context 'with less than 100 km in the window' do
    before { SummaryValue.find_by!(field: :car_odometer_1).update!(value: 80) }

    it { expect(estimate.km_per_percent(car)).to be_nil }
  end

  context 'with a car in use for less than the window' do
    before { car.update!(active_from: today - 10) }

    it { expect(estimate.km_per_percent(car)).to be_nil }
  end
end
