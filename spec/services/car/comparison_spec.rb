require 'rails_helper'

describe Car::Comparison do
  subject(:comparison) { Car::Report.new(Timeframe.new('2026-01'), [car]).comparison }

  let(:car) { Car.create!(id: 1, active_from: Date.new(2025, 1, 1), fuel_type: 'petrol', fuel_consumption: 8, combustion_tax: 365) }
  let(:electricity_price) { Price.at(name: :electricity, date: Date.new(2026, 1, 10)).to_f }
  let(:fuel_prices) { instance_double(Car::FuelPrices, any?: true) }

  def summary(date, field, aggregation, value)
    Summary.find_or_create_by!(date:)
    SummaryValue.create!(date:, field:, aggregation:, value:)
  end

  before do
    travel_to Date.new(2026, 9, 23).in_time_zone.change(hour: 12)
    allow(Car::FuelPrices).to receive(:new).with('petrol').and_return(fuel_prices)
    allow(fuel_prices).to receive(:at) { |date| 2.0 if date >= Date.new(2026, 1, 1) }

    # The odometer reads since December, so each window starts before the
    # charges
    summary(Date.new(2025, 12, 1), :car_odometer_1, :sum, 0)

    # 30 kWh, 10 kWh of them from the grid, for 4.60 EUR, and 150 km two
    # days later
    start = Date.new(2026, 1, 10).in_time_zone.change(hour: 12)
    ChargingSession.create!(kind: :wallbox, origin: :detection, car:, started_at: start, ended_at: start + 1.hour, kwh: 30, kwh_grid: 10, cost: 4.6, cost_grid: 3.0)
    summary(Date.new(2026, 1, 12), :car_odometer_1, :sum, 150)

    # 365 EUR less 73 EUR for 2026 is 0.80 EUR a day. The income of 2025 is
    # outside, and the comparison does not count a purchase.
    car.payments.create!(category: :ghg_quota, date: Date.new(2026, 3, 20), amount: 365)
    car.payments.create!(category: :vehicle_tax, date: Date.new(2026, 1, 25), amount: 73)
    car.payments.create!(category: :ghg_quota, date: Date.new(2025, 6, 1), amount: 999)
    car.payments.create!(category: :purchase, date: Date.new(2026, 1, 2), amount: 30_000)
  end

  it 'is possible and ready with fuel prices and a distance' do
    expect(comparison).to be_possible
    expect(comparison).to be_ready
  end

  it 'fills up the fuel for the distance at the price of each day' do
    expect(comparison.distance).to eq(150)
    expect(comparison.liters).to be_within(0.001).of(12)
    expect(comparison.fuel_cost).to be_within(0.001).of(24)
  end

  it 'gives the lowest and the highest fuel price of the dates' do
    allow(fuel_prices).to receive(:series).and_return([[Date.new(2026, 1, 1), 1.9], [Date.new(2026, 1, 12), 2.1], [Date.new(2026, 1, 31), 1.8]])

    expect(comparison.fuel_price_range).to eq(1.8..2.1)
  end

  it 'gives the energy of the car and its consumption' do
    expect(comparison.energy_wh).to be_within(0.001).of(30_000)
    expect(comparison.per_100km(comparison.energy_wh)).to be_within(0.001).of(20_000)
  end

  # Without PV, the grid gives the 20 kWh of PV too
  it 'splits the cost of the energy by its sources, with and without the PV system' do
    expect(comparison.sources.transform_values { [it.energy_wh.round, it.cost.round(2)] }).to eq(pv: [20_000, 1.6], grid: [10_000, 3.0])
    expect(comparison.sources_without_pv.transform_values { [it.energy_wh.round, it.cost.round(2)] }).to eq(grid: [30_000, (electricity_price * 30).round(2)])
  end

  # "all" adds the guest to the cars of the car page, but the guest has no
  # combustion car
  it 'leaves out the guest sessions' do
    start = Date.new(2026, 1, 11).in_time_zone.change(hour: 12)
    ChargingSession.create!(kind: :wallbox, origin: :detection, guest: true, started_at: start, ended_at: start + 1.hour, kwh: 20, kwh_grid: 20, cost: 6, cost_grid: 6)
    report = Car::Report.new(Timeframe.new('2026-01'), [car], guest: true)

    expect(report.value(:car_charging)).to eq(50_000)
    expect(report.comparison.energy_wh).to be_within(0.001).of(30_000)
    expect(report.comparison.cost).to be_within(0.001).of(4.6)
    expect(report.comparison.cost_without_pv).to be_within(0.001).of(electricity_price * 30)
    expect(report.comparison.sources.values.sum(&:cost)).to be_within(0.001).of(4.6)
  end

  it 'gives the driving cost of the car, with and without the PV system' do
    expect(comparison.cost).to be_within(0.001).of(4.6)
    expect(comparison.cost_without_pv).to be_within(0.001).of(electricity_price * 30)
  end

  # 365 EUR a year is 1 EUR a day, for the 31 days of January
  it 'counts the tax for each day of the period' do
    expect(comparison.tax).to be_within(0.001).of(31)
  end

  # The odometer reads since January 12, but the tax is due for the time
  it 'counts the tax before the first distance' do
    SummaryValue.where(date: Date.new(2025, 12, 1)).delete_all

    expect(comparison.tax).to be_within(0.001).of(31)
  end

  # 0.80 EUR for each of the 31 days of January, also before the dates of
  # the payments
  it 'spreads the payments of a year over its days, as a cost' do
    expect(comparison.payments).to be_within(0.001).of(-24.8)
  end

  # 365 EUR of GHG quota for 2026 is 1 EUR for each of the 31 days of
  # January, 73 EUR of vehicle tax 6.20 EUR. The purchase does not count.
  it 'gives the payments by their category' do
    expect(comparison.payment_costs.keys).to eq(%w[ghg_quota vehicle_tax])
    expect(comparison.payment_costs.values).to contain_exactly(be_within(0.001).of(-31), be_within(0.001).of(6.2))
  end

  it 'filters the list of the payments to the compared payments of the car in the year' do
    expect(comparison.payment_filter.to_params).to eq(
      car: car.id, category: Car::Payment::COMPARED, from: '2026-01-01', to: '2026-12-31',
    )
    expect(comparison.payment_filter(%w[ghg_quota]).to_params).to include(category: %w[ghg_quota])
  end

  it 'splits into periods, each with its part of the dates and of the payments' do
    months = Car::Report.new(Timeframe.new('2026'), [car]).comparison.split(:month).first(2)

    expect(months.map { |dates, month| [dates, month.dates] }).to eq(
      [
        [Date.new(2026, 1, 1)..Date.new(2026, 1, 31), Date.new(2026, 1, 1)..Date.new(2026, 1, 31)],
        [Date.new(2026, 2, 1)..Date.new(2026, 2, 28), Date.new(2026, 2, 1)..Date.new(2026, 2, 28)],
      ],
    )
    expect(months.map { it.last.payments }).to contain_exactly(be_within(0.001).of(-0.8 * 31), be_within(0.001).of(-0.8 * 28))
    expect(comparison.split(:year).map { |dates, year| [dates, year.dates] }).to eq(
      [[Date.new(2026, 1, 1)..Date.new(2026, 12, 31), Date.new(2026, 1, 1)..Date.new(2026, 1, 31)]],
    )
  end

  # 2026-01-01 is a Thursday, so the first week holds four days
  it 'splits into weeks from Monday to Sunday' do
    weeks = comparison.split(:week)

    expect(weeks.first(2).map { |dates, week| [dates, week.dates] }).to eq(
      [
        [Date.new(2025, 12, 29)..Date.new(2026, 1, 4), Date.new(2026, 1, 1)..Date.new(2026, 1, 4)],
        [Date.new(2026, 1, 5)..Date.new(2026, 1, 11), Date.new(2026, 1, 5)..Date.new(2026, 1, 11)],
      ],
    )
    expect(weeks.last.last.dates).to eq(Date.new(2026, 1, 26)..Date.new(2026, 1, 31))
  end

  it 'loads the payments once for all periods' do
    allow(Car::Payment).to receive(:compared).and_call_original

    Car::Report.new(Timeframe.new('2026'), [car]).comparison.split(:month).each { it.last.payments }

    expect(Car::Payment).to have_received(:compared).once
  end

  it 'sums the cost of each column' do
    expect(comparison.combustion_cost).to be_within(0.001).of(55)
    expect(comparison.car_cost).to be_within(0.001).of(-20.2)
    expect(comparison.combustion_cost - comparison.car_cost).to be_within(0.001).of(75.2)
    expect(comparison.per_100km(comparison.car_cost)).to be_within(0.001).of(-20.2 * 100 / 150)
    expect(comparison.combustion_cost - comparison.car_cost_without_pv).to be_within(0.001).of(55 - ((electricity_price * 30) - 24.8))
  end

  # 365 EUR a year is 31 EUR for January, on both sides
  context 'with a running cost' do
    before { car.payments.create!(category: :insurance, date: Date.new(2026, 1, 2), amount: 365) }

    it 'adds it to the cost of both cars and keeps the savings' do
      expect(comparison.shared_cost).to be_within(0.001).of(31)
      expect(comparison.payments).to be_within(0.001).of(-24.8 + 31)
      expect(comparison.combustion_cost).to be_within(0.001).of(55 + 31)
      expect(comparison.car_cost).to be_within(0.001).of(-20.2 + 31)
      expect(comparison.combustion_cost - comparison.car_cost).to be_within(0.001).of(75.2)
    end

    # A refund of 73 EUR leaves 292 EUR, 24.8 EUR for January
    it 'lowers it by a refund of its category' do
      car.payments.create!(category: :insurance, date: Date.new(2026, 5, 4), amount: -73)

      expect(comparison.payment_costs['insurance']).to be_within(0.001).of(24.8)
      expect(comparison.shared_cost).to be_within(0.001).of(24.8)
    end
  end

  context 'with a whole year' do
    subject(:comparison) { Car::Report.new(Timeframe.new('2025'), [car]).comparison }

    it 'counts each payment of the year in full' do
      expect(comparison.payments).to be_within(0.001).of(-999)
    end
  end

  # Up to September 23, 266 of the 365 days of 2026
  context 'with the current year' do
    subject(:comparison) { Car::Report.new(Timeframe.new('2026'), [car]).comparison }

    it 'counts the part of the payments up to today' do
      expect(comparison.payments).to be_within(0.001).of(-0.8 * 266)
    end
  end

  # The car ends on March 31, so the income spreads over 90 days
  context 'with a period of use in a part of the year' do
    before { car.update!(active_until: Date.new(2026, 3, 31)) }

    it 'spreads the payments over the days of use' do
      expect(comparison.payments).to be_within(0.001).of(-292 * 31 / 90.0)
    end
  end

  context 'without a fuel price on the day of the trip' do
    before { allow(fuel_prices).to receive(:at) { |date| 2.0 if date >= Date.new(2026, 2, 1) } }

    it 'leaves out the distance of the day on all sides' do
      expect(comparison.distance).to eq(0)
      expect(comparison.fuel_cost).to eq(0)
      expect(comparison.cost).to eq(0)
    end

    it 'still counts the tax, which is due for the time' do
      expect(comparison.tax).to be_within(0.001).of(31)
    end
  end

  context 'without fuel prices in InfluxDB' do
    let(:fuel_prices) { instance_double(Car::FuelPrices, any?: false, at: nil) }

    it 'is not possible' do
      expect(comparison).not_to be_possible
      expect(comparison).not_to be_ready
    end
  end

  # A month without a drive has no distance to compare
  context 'without a drive' do
    subject(:comparison) { Car::Report.new(Timeframe.new('2026-02'), [car]).comparison }

    it 'is possible, but not ready' do
      expect(comparison).to be_possible
      expect(comparison).not_to be_ready
    end
  end

  context 'without a fuel of the car' do
    before { car.update!(fuel_type: nil) }

    it 'has no comparison' do
      expect(comparison).to be_nil
    end
  end

  describe '.timeframe?' do
    it 'takes a timeframe of whole days' do
      %w[2026-01-10 2026-W03 2026-02 2026 P7D P1M P2Y all 2026-01-01..2026-01-02].each do
        expect(described_class.timeframe?(Timeframe.new(it))).to be(true), it
      end
    end

    it 'rejects the live view and the last hours' do
      %w[now P24H].each do
        expect(described_class.timeframe?(Timeframe.new(it))).to be(false), it
      end
    end
  end

  describe '.timeframe' do
    it 'takes the live view and the last hours as today' do
      %w[now P24H].each do
        expect(described_class.timeframe(Timeframe.new(it)).to_param).to eq(Date.current.iso8601), it
      end
    end
  end
end
