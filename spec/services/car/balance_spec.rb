require 'rails_helper'

describe Car::Balance do
  subject(:balance) { described_class.new(data, cars: selected_cars) }

  let(:cars) { [Car.create!(id: 1), Car.create!(id: 2)] }
  let(:selected_cars) { cars }
  let(:timeframe) { Timeframe.new('2026-01') }
  let(:data) do
    Sensor::Data::Single.new(
      { %i[car_mileage_1 sum] => 120, %i[car_mileage_2 sum] => 80, %i[car_max_range_1 avg] => 400 },
      timeframe:,
    )
  end
  let(:driving) do
    Car::DailyRates::Totals.new(distance: 200, energy_wh: 40_000, cost_distance: 200, cost: 10.0)
  end

  def wallbox(day, kwh:, car_id: nil, guest: false, cost: nil, kwh_grid: nil)
    start = Time.zone.local(2026, 1, day, 12)
    ChargingSession.create!(kind: :wallbox, car_id:, guest:, started_at: start, ended_at: start + 1.hour, kwh:, kwh_grid:, cost:)
  end

  before do
    allow(Car::DailyRates).to receive(:for).with(timeframe, selected_cars, sessions: anything).and_return(
      instance_double(Car::DailyRates::Sum, totals: driving),
    )

    wallbox(10, kwh: 10, kwh_grid: 4, cost: 1.6, car_id: 1)
    wallbox(11, kwh: 20, kwh_grid: 0, cost: 2.0, car_id: 2)
    wallbox(12, kwh: 5, guest: true, cost: 1.5)
    wallbox(13, kwh: 7)
    ChargingSession.create!(kind: :offsite, car_id: 1, started_at: Time.zone.local(2026, 1, 14, 12), kwh: 8, cost: 4.0)
  end

  describe '#car_distance' do
    it 'adds the distance of the selected cars' do
      expect(balance.car_distance).to eq(200)
    end

    context 'with one car selected' do
      let(:selected_cars) { [cars.second] }

      it { expect(balance.car_distance).to eq(80) }
    end
  end

  describe '#car_max_range' do
    it 'has none for "all"' do
      expect(balance.car_max_range).to be_nil
    end

    context 'with one car selected' do
      let(:selected_cars) { [cars.first] }

      it { expect(balance.car_max_range).to eq(400) }
    end
  end

  describe '#car_driving_costs' do
    it 'is the driving cost of the days of the period' do
      expect(balance.car_driving_costs).to eq(10.0)
    end

    context 'without a cost rate' do
      let(:driving) { Car::DailyRates::Totals.new(distance: 200, energy_wh: 40_000, cost_distance: 0, cost: 0) }

      it { expect(balance.car_driving_costs).to be_nil }
    end
  end

  describe 'the charging of "all"' do
    it 'is the sum of the sessions of the cars, without the guest and the open sessions' do
      expect(balance.charged_wh).to eq(38_000)
      expect(balance.charging_costs).to be_within(0.001).of(7.6)
    end

    it 'counts the wallbox sessions of the cars, without the guest and the open sessions' do
      expect(balance.session_totals(:wallbox)).to match(count: 2, wh: 30_000, cost: be_within(0.001).of(3.6))
    end

    it 'counts the offsite sessions' do
      expect(balance.session_totals(:offsite)).to eq(count: 1, wh: 8_000, cost: 4.0)
    end

    it 'names the guest sessions and their loss' do
      expect(balance.session_totals(:guest)).to eq(count: 1, wh: 5_000, cost: 1.5)
    end

    it 'names the sessions that are not assigned' do
      expect(balance.session_totals(:not_assigned)).to include(count: 1, wh: 7_000)
    end

    it 'knows that a session has no cost' do
      wallbox(15, kwh: 3, car_id: 1)

      expect(balance).not_to be_charging_costs_complete
    end
  end

  describe 'a session in the window of the rates, outside the period' do
    before do
      ChargingSession.create!(kind: :offsite, car_id: 1, started_at: Time.zone.local(2025, 12, 25, 12), kwh: 50, cost: 9.0)
    end

    it 'does not count for the charging of the period' do
      expect(balance.charged_wh).to eq(38_000)
    end

    it 'goes to the rates with the sessions of the period, from one query' do
      queries = []
      ActiveSupport::Notifications.subscribed(->(*, payload) { queries << payload[:name] }, 'sql.active_record') do
        balance.driving
        balance.charged_wh
      end

      expect(Car::DailyRates).to have_received(:for).with(
        timeframe,
        selected_cars,
        sessions: include(an_object_having_attributes(kwh: 50), an_object_having_attributes(kwh: 8)),
      )
      expect(queries.count('ChargingSession Load')).to eq(1)
    end
  end

  describe 'the charging of one car' do
    let(:selected_cars) { [cars.first] }

    it 'is the sum of the sessions of the car' do
      expect(balance.charged_wh).to eq(18_000)
      expect(balance.charging_costs).to be_within(0.001).of(5.6)
    end
  end

  describe '#live' do
    let(:timeframe) { Timeframe.now }
    let(:data) do
      Sensor::Data::Single.new(
        { car_battery_soc_1: 80, car_range_1: 300, car_max_range_1: 375, car_mileage_1: 12_345, car_battery_soc_2: 40 },
        timeframe:,
      )
    end

    it 'gives the values of each selected car' do
      expect(balance.live.map(&:to_h)).to eq(
        [
          { car: cars.first, soc: 80, range: 300, max_range: 375, odometer: 12_345 },
          { car: cars.last, soc: 40, range: nil, max_range: nil, odometer: nil },
        ],
      )
    end
  end
end
