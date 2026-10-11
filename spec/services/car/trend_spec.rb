describe Car::Trend do
  subject(:trend) do
    described_class.new(sensor: Sensor::Registry[:car_distance], timeframe:, current_value: 150, base:, cars:)
  end

  let(:cars) { [Car.create!(id: 1, active_from: Date.new(2025, 1, 1))] }
  let(:timeframe) { Timeframe.new('2026-01') }
  let(:base) { :previous_year }

  def summary(date, value)
    Summary.find_or_create_by!(date:)
    SummaryValue.create!(date:, field: 'car_odometer_1', aggregation: 'sum', value:)
  end

  before do
    travel_to Time.zone.local(2026, 9, 23, 12)

    summary(Date.new(2025, 1, 1), 0)
    summary(Date.new(2025, 1, 10), 100)
  end

  it 'compares the value with the report of the previous year' do
    expect(trend.base_value).to eq(100)
    expect(trend.percent).to eq(50)
  end

  context 'with a base period before the first day of use' do
    let(:timeframe) { Timeframe.new('2025-01') }

    it { expect(trend.base_value).to be_nil }
  end

  context 'with a base period without a value' do
    let(:base) { :previous_period }

    it { expect(trend.base_value).to be_nil }
  end
end
