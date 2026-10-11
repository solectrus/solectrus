require 'rails_helper'

describe Car::Driving do
  subject(:driving) { described_class.new(Car::Ledger.new(cars, described_class.reach(quarter, min_date:)), min_date:) }

  let(:car) { Car.create!(id: 1) }
  let(:cars) { [car] }
  let(:today) { Date.new(2026, 9, 23) }
  let(:min_date) { Date.new(2025, 1, 1) }
  let(:quarter) { Date.new(2026, 1, 1)..Date.new(2026, 3, 31) }

  def summary(date, field, aggregation, value)
    Summary.find_or_create_by!(date:)
    SummaryValue.create!(date:, field:, aggregation:, value:)
  end

  # Grid energy at 0.30 EUR/kWh, or without a cost
  def charge(date, energy_wh, cost: true, car_record: car, hour: 12, **attributes)
    start = date.in_time_zone.change(hour:)
    kwh = energy_wh / 1000.0
    ChargingSession.create!(
      kind: :wallbox,
      origin: :detection,
      car: car_record,
      started_at: start,
      ended_at: start + 1.hour,
      kwh:,
      kwh_grid: kwh,
      cost: (kwh * 0.30 if cost),
      **attributes,
    )
  end

  def january = driving.totals(Date.new(2026, 1, 1)..Date.new(2026, 1, 31))

  before do
    travel_to today.in_time_zone.change(hour: 12)

    # January: 30 kWh for 9 EUR, and 150 km two days later
    charge(Date.new(2026, 1, 10), 30_000)
    summary(Date.new(2026, 1, 12), :car_odometer_1, :sum, 150)

    # February: 50 km, but no charge in the 14 days before and after
    summary(Date.new(2026, 2, 20), :car_odometer_1, :sum, 50)

    # March: 100 km, and 10 kWh for 3 EUR five days later
    summary(Date.new(2026, 3, 20), :car_odometer_1, :sum, 100)
    charge(Date.new(2026, 3, 25), 10_000)
  end

  describe '#totals' do
    it 'drives each day at the rate of its own window' do
      expect(january.distance).to eq(150)
      expect(january.cost).to be_within(0.001).of(9.0)
      expect(january.cost_per_100km).to be_within(0.001).of(6.0)
      expect(january.consumption_per_100km).to be_within(0.001).of(20.0)
    end

    it 'gives no rate to a window with less than 100 km' do
      totals = driving.totals(Date.new(2026, 2, 1)..Date.new(2026, 2, 28))

      expect(totals).not_to be_rated
      expect(totals.cost_per_100km).to be_nil
    end

    # 9 EUR + 3 EUR for 150 km + 100 km. The 50 km of February have no rate.
    it 'sums the days of all dates' do
      totals = driving.totals(quarter)

      expect(totals.distance).to eq(250)
      expect(totals.cost).to be_within(0.001).of(12.0)
      expect(totals.cost_per_100km).to be_within(0.001).of(4.8)
    end

    it 'gives no cost rate to a window with a session without a cost' do
      charge(Date.new(2026, 1, 11), 5_000, cost: false)

      expect(january).to be_rated
      expect(january).not_to be_cost_rated
      expect(january.cost_per_100km).to be_nil
      expect(january.consumption_per_100km).to be_within(0.001).of(23.333)
    end

    it 'adds up: the months give the quarter' do
      months = [1, 2, 3].map { driving.totals(Date.new(2026, it, 1).all_month) }

      expect(months.sum(&:cost)).to be_within(0.001).of(driving.totals(quarter).cost)
    end

    it 'counts an offsite session' do
      ChargingSession.create!(kind: :offsite, origin: :user, car:, started_at: Date.new(2026, 1, 11).in_time_zone.change(hour: 12), kwh: 15, cost: 7.5)

      expect(january.consumption_per_100km).to be_within(0.001).of(30.0)
      expect(january.cost_per_100km).to be_within(0.001).of(11.0)
    end

    it 'counts no guest session, no session without a car and no session of another car' do
      charge(Date.new(2026, 1, 11), 5_000, car_record: nil, guest: true, hour: 18)
      charge(Date.new(2026, 1, 11), 6_000, car_record: nil, hour: 19)
      charge(Date.new(2026, 1, 11), 7_000, car_record: Car.create!(id: 2), hour: 20)

      expect(january.consumption_per_100km).to be_within(0.001).of(20.0)
    end

    # The window of January 12 ends on January 26
    it 'books a session to the local date of its start' do
      charge(Date.new(2026, 1, 26), 15_000, hour: 23)
      charge(Date.new(2026, 1, 27), 15_000, hour: 0)

      expect(january.consumption_per_100km).to be_within(0.001).of(30.0)
    end

    it 'ends the windows at the period of the car' do
      car.update!(active_from: Date.new(2026, 1, 11))

      # The charge of January 10 belongs to the car before
      expect(january.distance).to eq(0)
    end

    context 'with two cars' do
      let(:cars) { [car, Car.create!(id: 2)] }

      before do
        charge(Date.new(2026, 1, 12), 20_000, car_record: cars.last)
        summary(Date.new(2026, 1, 12), :car_odometer_2, :sum, 100)
      end

      it 'adds the cars, each at its own rate' do
        expect(january.distance).to eq(250)
        expect(january.cost).to be_within(0.001).of(15.0)
      end

      it 'reads the distances and the sessions of all cars in one query each' do
        queries = []
        ActiveSupport::Notifications.subscribed(->(*, payload) { queries << payload[:name] }, 'sql.active_record') do
          [1, 2, 3].each { driving.totals(Date.new(2026, it, 1).all_month) }
        end

        expect(queries.tally).to include('SummaryValue Pluck' => 1, 'ChargingSession Pluck' => 1)
      end
    end
  end

  describe '.reach' do
    it 'adds the margin on each side' do
      expect(described_class.reach(quarter, min_date:)).to eq(Date.new(2025, 12, 18)..Date.new(2026, 4, 14))
    end

    it 'ends today' do
      expect(described_class.reach(Date.new(2026, 9, 1)..today, min_date:)).to eq(Date.new(2026, 8, 18)..today)
    end

    it 'starts at the installation date' do
      expect(described_class.reach(Date.new(2025, 1, 1)..Date.new(2025, 1, 31), min_date:)).to eq(min_date..Date.new(2025, 2, 14))
    end
  end
end
