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

    # The odometer reads since December, so each window starts before the
    # charges
    summary(Date.new(2025, 12, 1), :car_odometer_1, :sum, 0)

    # January: 30 kWh for 9 EUR, and 150 km two days later
    charge(Date.new(2026, 1, 10), 30_000)
    summary(Date.new(2026, 1, 12), :car_odometer_1, :sum, 150)

    # March: 100 km, and 10 kWh for 3 EUR five days later
    summary(Date.new(2026, 3, 20), :car_odometer_1, :sum, 100)
    charge(Date.new(2026, 3, 25), 10_000)
  end

  # February: 50 km, but no charge in the 28 days before and after
  def drive_in_february = summary(Date.new(2026, 2, 20), :car_odometer_1, :sum, 50)

  # The energy (Wh) and the cost of a km at the window of a date, before the
  # balance of a month or a year scales it
  def window_rate(date) = driving.rate(car, date)

  describe '#totals' do
    it 'drives each day at the rate of its own window' do
      expect(january.distance).to eq(150)
      expect(january.cost).to be_within(0.001).of(9.0)
      expect(january.cost_per_100km).to be_within(0.001).of(6.0)
      expect(january.consumption_per_100km).to be_within(0.001).of(20.0)
    end

    # The window of February 20 widens to 42 days before and after, from
    # January 9 to April 3: 300 km, 40 kWh and 12 EUR
    it 'widens a window without a charge until it holds one' do
      drive_in_february

      expect(window_rate(Date.new(2026, 2, 20)).energy_wh).to be_within(0.001).of(40_000.0 / 300)
      expect(window_rate(Date.new(2026, 2, 20)).cost).to be_within(0.000001).of(12.0 / 300)
    end

    # The charges are 43 days before and after February 20
    it 'gives no rate without a charge in the widest window' do
      drive_in_february
      ChargingSession.delete_all
      charge(Date.new(2026, 1, 8), 30_000)
      charge(Date.new(2026, 4, 4), 10_000)

      totals = driving.totals(Date.new(2026, 2, 1)..Date.new(2026, 2, 28))

      expect(totals).not_to be_rated
      expect(totals.cost_per_100km).to be_nil
    end

    # 9 EUR + 3 EUR for 150 km + 100 km
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

      expect(window_rate(Date.new(2026, 1, 12)).energy_wh).to be_within(0.001).of(45_000.0 / 150)
    end

    it 'ends the windows at the period of the car' do
      car.update!(active_from: Date.new(2026, 1, 11))

      # The charge of January 10 belongs to the car before
      expect(january.distance).to eq(0)
    end

    # The charge of January 10 has no kilometers, because the odometer reads
    # since January 12
    it 'starts the windows at the first distance' do
      SummaryValue.where(date: Date.new(2025, 12, 1)).delete_all
      charge(Date.new(2026, 1, 12), 15_000, hour: 18)

      expect(window_rate(Date.new(2026, 1, 12)).energy_wh).to be_within(0.001).of(15_000.0 / 150)
    end

    # The window of January 12 runs from December 29 to January 26. Its
    # battery holds 10 percentage points more at its end, which is 5 kWh at
    # 0.5 kWh per percent.
    context 'with the state of charge at the start and the end of the window' do
      def kwh_per_percent = 0.5

      before do
        allow(ChargingSession).to receive(:kwh_per_percent).and_return(car.id => kwh_per_percent)
        summary(Date.new(2025, 12, 28), :car_battery_soc_1, :last, 50)
        summary(Date.new(2026, 1, 26), :car_battery_soc_1, :last, 60)
      end

      it 'drives on the charged energy less the energy that stays in the battery' do
        expect(window_rate(Date.new(2026, 1, 12)).energy_wh).to be_within(0.001).of(25_000.0 / 150)
      end

      # The energy in the battery has the average price of the window
      it 'gives the cost the same share' do
        expect(window_rate(Date.new(2026, 1, 12)).cost).to be_within(0.000001).of(7.5 / 150)
      end

      context 'without the energy of a percent' do
        def kwh_per_percent = nil

        it 'drives on the charged energy' do
          expect(window_rate(Date.new(2026, 1, 12)).energy_wh).to be_within(0.001).of(30_000.0 / 150)
        end
      end

      context 'without the state of charge at the start of the window' do
        before { SummaryValue.where(date: Date.new(2025, 12, 28)).delete_all }

        it 'drives on the charged energy' do
          expect(window_rate(Date.new(2026, 1, 12)).energy_wh).to be_within(0.001).of(30_000.0 / 150)
        end
      end
    end

    # The battery holds 10 percentage points more at the end of January than
    # at the end of December: 5 kWh at 0.5 kWh per percent. The windows at
    # both ends have the price of the charge of January 10, 0.30 EUR/kWh, so
    # the 5 kWh are worth 1.50 EUR.
    context 'with the state of charge at the ends of a month' do
      def soc(date, value) = summary(date, :car_battery_soc_1, :last, value)

      before do
        allow(ChargingSession).to receive(:kwh_per_percent).and_return(car.id => 0.5)
        soc(Date.new(2025, 12, 31), 50)
        soc(Date.new(2026, 1, 31), 60)
      end

      it 'scales the days of the month to its balance' do
        expect(january.energy_wh).to be_within(0.001).of(25_000)
        expect(january.cost).to be_within(0.001).of(7.5)
        expect(driving.totals(Date.new(2026, 1, 12)..Date.new(2026, 1, 12)).energy_wh).to be_within(0.001).of(25_000)
      end

      # January then joins the months of its year without the state of
      # charge, which hold the charged 40 kWh
      it 'scales a month without the state of charge at an end with its year' do
        SummaryValue.where(date: Date.new(2026, 1, 31)).delete_all

        expect(january.energy_wh).to be_within(0.001).of(30_000)
      end

      it 'keeps the current month, which has no end yet' do
        travel_to Date.new(2026, 1, 31).in_time_zone.change(hour: 12)

        expect(january.energy_wh).to be_within(0.001).of(30_000)
      end

      # 35 kWh less 5 kWh, but the cost of the session without a cost is missing
      it 'scales the energy alone with a session without a cost' do
        charge(Date.new(2026, 1, 11), 5_000, cost: false)

        expect(january.energy_wh).to be_within(0.001).of(30_000)
        expect(january).not_to be_cost_rated
      end

      # 30 kWh and 40 kWh out of the battery give a factor of 70/30
      it 'keeps a month whose factor hints at missing data' do
        SummaryValue.find_by(date: Date.new(2025, 12, 31)).update!(value: 90)
        SummaryValue.find_by(date: Date.new(2026, 1, 31)).update!(value: 10)

        expect(january.energy_wh).to be_within(0.001).of(30_000)
      end
    end

    # Without the state of charge, the past months of 2026 scale together to
    # the charged 40 kWh and 12 EUR. The window of February 20 counts both
    # charges, so the windows hold 46.67 kWh and 14 EUR (see above).
    context 'with the months of a year without the state of charge' do
      before { drive_in_february }

      it 'scales the months together to their charged energy and their charging cost' do
        totals = driving.totals(Date.new(2026, 1, 1)..Date.new(2026, 8, 31))

        expect(totals.energy_wh).to be_within(0.001).of(40_000)
        expect(totals.cost).to be_within(0.001).of(12.0)
        expect(january.energy_wh).to be_within(0.001).of(30_000.0 * 6 / 7)
      end

      it 'keeps the current month, which has no end yet' do
        travel_to Date.new(2026, 3, 31).in_time_zone.change(hour: 12)

        expect(driving.totals(Date.new(2026, 3, 1).all_month).energy_wh).to be_within(0.001).of(10_000)
      end

      # February has no rate, so January and March hold the charged 40 kWh
      it 'leaves out a month with a distance without a rate' do
        ChargingSession.delete_all
        charge(Date.new(2026, 1, 8), 30_000)
        charge(Date.new(2026, 4, 4), 10_000)

        expect(driving.totals(Date.new(2026, 2, 1).all_month)).not_to be_rated
        expect(driving.totals(Date.new(2026, 1, 1)..Date.new(2026, 8, 31)).energy_wh).to be_within(0.001).of(40_000)
      end
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

      it 'reads the distances, the sessions and the energy of a percent of all cars in one query each' do
        queries = []
        ActiveSupport::Notifications.subscribed(->(*, payload) { queries << payload[:name] }, 'sql.active_record') do
          [1, 2, 3].each { driving.totals(Date.new(2026, it, 1).all_month) }
        end

        expect(queries.tally).to include('SummaryValue Pluck' => 1, 'ChargingSession Pluck' => 2)
      end
    end
  end

  describe '.reach' do
    # The year of the dates, less 42 days and the day before the first window
    it 'reads the calendar years of the dates, with the widest margin before them' do
      expect(described_class.reach(Date.new(2026, 2, 10)..Date.new(2026, 2, 12), min_date:)).to eq(Date.new(2025, 11, 19)..today)
    end

    it 'ends today' do
      expect(described_class.reach(Date.new(2026, 9, 1)..today, min_date:).end).to eq(today)
    end

    # The end of 2025 and 42 days
    it 'starts at the installation date' do
      expect(described_class.reach(Date.new(2025, 1, 1)..Date.new(2025, 1, 31), min_date:)).to eq(min_date..Date.new(2026, 2, 11))
    end
  end

  # The rate of a date needs its windows alone, not the factors of its month
  describe '.window_reach' do
    it 'adds the widest margin on each side, and the day before the first window' do
      expect(described_class.window_reach(quarter, min_date:)).to eq(Date.new(2025, 11, 19)..Date.new(2026, 5, 12))
    end
  end
end
