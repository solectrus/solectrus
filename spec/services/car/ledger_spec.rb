require 'rails_helper'

describe Car::Ledger do
  subject(:ledger) { described_class.new(dates, car:) }

  let(:car) { Car.create!(id: 1) }
  let(:other_car) { Car.create!(id: 2) }
  let(:first_day) { Date.new(2026, 6, 1) }
  let(:last_day) { Date.new(2026, 6, 30) }
  let(:dates) { first_day..last_day }

  def distance(date, value, number: 1)
    Summary.find_or_create_by!(date:)
    SummaryValue.create!(date:, field: :"car_mileage_#{number}", aggregation: :sum, value:)
  end

  # The session of the first car, unless the attributes say otherwise
  def wallbox(date, kwh:, hour: 12, **attributes)
    start = date.in_time_zone.change(hour:)
    ChargingSession.create!(
      { kind: :wallbox, car_id: 1, started_at: start, ended_at: start + 1.hour, kwh: }.merge(attributes),
    )
  end

  def offsite(date, kwh:, cost:, hour: 12, min: 0)
    ChargingSession.create!(kind: :offsite, car:, started_at: date.in_time_zone.change(hour:, min:), kwh:, cost:)
  end

  before do
    car
    other_car

    # 10 kWh at the start of the range: 6 kWh grid, 4 kWh PV
    wallbox(first_day, kwh: 10, kwh_grid: 6, cost: 2.2)
    distance(first_day, 20)

    # 20 kWh at the end of the range, all PV
    wallbox(last_day, kwh: 20, kwh_grid: 0, cost: 2.0)
    distance(last_day, 80)
  end

  describe '#totals' do
    it 'sums the full range' do
      totals = ledger.totals

      expect(totals.distance).to eq(100)
      expect(totals.energy_wh).to eq(30_000)
      expect(totals.cost).to be_within(0.001).of(4.2)
    end

    it 'sums a part of the range' do
      totals = ledger.totals(last_day..last_day)

      expect(totals.distance).to eq(80)
      expect(totals.energy_wh).to eq(20_000)
      expect(totals.cost).to be_within(0.001).of(2.0)
    end

    it 'counts a day outside the range of the ledger as empty' do
      distance(last_day + 1, 500)

      expect(ledger.totals(last_day..(last_day + 1)).distance).to eq(80)
    end

    it 'gives empty totals for a range outside the ledger' do
      expect(ledger.totals((last_day + 1)..(last_day + 5)).distance).to eq(0)
    end

    it 'adds the energy and the cost of an offsite session' do
      offsite(first_day, kwh: 5, cost: 2.5)

      totals = ledger.totals

      expect(totals.energy_wh).to eq(35_000)
      expect(totals.cost).to be_within(0.001).of(6.7)
    end

    it 'counts no guest session and no session of another car' do
      wallbox(first_day, kwh: 5, car_id: nil, guest: true, hour: 18)
      wallbox(first_day, kwh: 6, car_id: nil, hour: 19)
      wallbox(first_day, kwh: 7, car_id: 2, hour: 20)
      distance(first_day, 300, number: 2)

      totals = ledger.totals

      expect(totals.energy_wh).to eq(30_000)
      expect(totals.distance).to eq(100)
    end

    it 'counts the sessions without a cost' do
      wallbox(first_day, kwh: 3, hour: 18)

      expect(ledger.totals).not_to be_costed
      expect(ledger.totals(last_day..last_day)).to be_costed
    end

    it 'books a session to the local date of its start' do
      offsite(last_day, kwh: 5, cost: 2.5, hour: 23, min: 30)
      offsite(last_day + 1, kwh: 7, cost: 3.5, hour: 0, min: 30)

      expect(ledger.totals(last_day..last_day).energy_wh).to eq(25_000)
    end

    it 'reads the database once for many parts' do
      ledger.totals

      queries = 0
      ActiveSupport::Notifications.subscribed(->(*) { queries += 1 }, 'sql.active_record') do
        dates.each { |date| ledger.totals(date..date) }
      end

      expect(queries).to eq(0)
    end
  end

  context 'with sessions that the caller has loaded' do
    subject(:ledger) { described_class.new(dates, car:, sessions: ChargingSession.all.to_a) }

    before do
      wallbox(first_day, kwh: 7, car_id: 2, hour: 20)
      offsite(last_day + 1, kwh: 5, cost: 2.5)
    end

    it 'takes the sessions of the car in its dates' do
      expect(ledger.totals.energy_wh).to eq(30_000)
    end

    it 'reads no session' do
      ledger
      queries = []
      ActiveSupport::Notifications.subscribed(->(*, payload) { queries << payload[:name] }, 'sql.active_record') do
        ledger.totals
      end

      expect(queries).not_to include('ChargingSession Load')
    end
  end
end
