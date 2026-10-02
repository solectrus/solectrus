require 'rails_helper'

describe Car::DailyRates do
  subject(:daily_rates) { described_class.new(dates, car:, bounds: min_date..today) }

  let(:car) { Car.create!(id: 1) }
  let(:today) { Date.new(2026, 9, 23) }
  let(:min_date) { Date.new(2025, 1, 1) }
  let(:dates) { Date.new(2026, 1, 1)..Date.new(2026, 3, 31) }

  def summary(date, field, aggregation, value)
    Summary.find_or_create_by!(date:)
    SummaryValue.create!(date:, field:, aggregation:, value:)
  end

  # Grid energy at 0.30 EUR/kWh, or without a cost
  def charge(date, energy_wh, cost: true, car_record: car)
    start = date.in_time_zone.change(hour: 12)
    kwh = energy_wh / 1000.0
    ChargingSession.create!(
      kind: :wallbox,
      car: car_record,
      started_at: start,
      ended_at: start + 1.hour,
      kwh:,
      kwh_grid: kwh,
      cost: (kwh * 0.30 if cost),
    )
  end

  before do
    travel_to today.in_time_zone.change(hour: 12)

    # January: 30 kWh for 9 EUR, and 150 km two days later
    charge(Date.new(2026, 1, 10), 30_000)
    summary(Date.new(2026, 1, 12), :car_mileage_1, :sum, 150)

    # February: 50 km, but no charge in the 14 days before and after
    summary(Date.new(2026, 2, 20), :car_mileage_1, :sum, 50)

    # March: 100 km, and 10 kWh for 3 EUR five days later
    summary(Date.new(2026, 3, 20), :car_mileage_1, :sum, 100)
    charge(Date.new(2026, 3, 25), 10_000)
  end

  describe '#totals' do
    it 'drives each day at the rate of its own window' do
      totals = daily_rates.totals(Date.new(2026, 1, 1)..Date.new(2026, 1, 31))

      expect(totals.distance).to eq(150)
      expect(totals.cost).to be_within(0.001).of(9.0)
      expect(totals.cost_per_100km).to be_within(0.001).of(6.0)
      expect(totals.consumption_per_100km).to be_within(0.001).of(20.0)
    end

    it 'gives no rate to a period without a rate' do
      totals = daily_rates.totals(Date.new(2026, 2, 1)..Date.new(2026, 2, 28))

      expect(totals).not_to be_rated
      expect(totals.cost_per_100km).to be_nil
    end

    # 9 EUR + 3 EUR for 150 km + 100 km. The 50 km of February have no rate.
    it 'sums the days of all dates' do
      totals = daily_rates.totals

      expect(totals.distance).to eq(250)
      expect(totals.cost).to be_within(0.001).of(12.0)
      expect(totals.cost_per_100km).to be_within(0.001).of(4.8)
    end

    it 'gives no cost rate to a window with a session without a cost' do
      charge(Date.new(2026, 1, 11), 5_000, cost: false)

      totals = daily_rates.totals(Date.new(2026, 1, 1)..Date.new(2026, 1, 31))

      expect(totals).to be_rated
      expect(totals).not_to be_cost_rated
      expect(totals.cost_per_100km).to be_nil
      expect(totals.consumption_per_100km).to be_within(0.001).of(23.333)
    end

    it 'adds up: the months give the quarter' do
      months = [1, 2, 3].map { daily_rates.totals(Date.new(2026, it, 1).all_month) }

      expect(months.sum(&:cost)).to be_within(0.001).of(daily_rates.totals.cost)
    end
  end

  describe '#rate_on' do
    it 'gives the charged energy and cost of the window for each km' do
      rate = daily_rates.rate_on(Date.new(2026, 1, 12))

      expect(rate.wh_per_km).to be_within(0.001).of(200)
      expect(rate.cost_per_km).to be_within(0.001).of(0.06)
    end

    it 'gives no rate to a window with less than 100 km' do
      expect(daily_rates.rate_on(Date.new(2026, 2, 20))).to be_nil
    end
  end

  describe '#ledger_dates' do
    it 'is the dates plus the margin on each side' do
      expect(daily_rates.ledger_dates).to eq(Date.new(2025, 12, 18)..Date.new(2026, 4, 14))
    end

    context 'with a recent period' do
      let(:dates) { Date.new(2026, 9, 1)..today }

      it 'ends today' do
        expect(daily_rates.ledger_dates).to eq(Date.new(2026, 8, 18)..today)
      end
    end

    context 'with a period near the installation date' do
      let(:dates) { Date.new(2025, 1, 1)..Date.new(2025, 1, 31) }

      it 'starts at the installation date' do
        expect(daily_rates.ledger_dates).to eq(min_date..Date.new(2025, 2, 14))
      end
    end
  end

  describe '.for' do
    let(:timeframe) { Timeframe.new('2026-01', min_date:) }

    it 'takes the dates and the installation date of the timeframe' do
      rates = described_class.for(timeframe, [car])

      expect(rates.rates.sole.dates).to eq(Date.new(2026, 1, 1)..Date.new(2026, 1, 31))
    end

    it 'ends the windows at the period of the car' do
      car.update!(active_from: Date.new(2026, 1, 11))

      # The charge of January 10 belongs to the car before
      expect(described_class.for(timeframe, [car]).totals.distance).to eq(0)
    end

    it 'adds the cars' do
      other = Car.create!(id: 2)
      charge(Date.new(2026, 1, 12), 20_000, car_record: other)
      summary(Date.new(2026, 1, 12), :car_mileage_2, :sum, 100)

      totals = described_class.for(timeframe, [car, other]).totals

      expect(totals.distance).to eq(250)
      expect(totals.cost).to be_within(0.001).of(15.0)
    end

    it 'includes the days around the dates in the days to build' do
      rates = described_class.for(Timeframe.new('2026-06-26', min_date:), [car])

      expect(rates.missing_or_stale_days).to include(
        Date.new(2026, 6, 12),
        Date.new(2026, 6, 26),
        Date.new(2026, 7, 10),
      )
    end
  end
end
