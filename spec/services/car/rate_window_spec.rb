require 'rails_helper'

describe Car::RateWindow do
  let(:today) { Date.new(2026, 9, 23) }

  before { travel_to today.in_time_zone.change(hour: 12) }

  describe '.with_margin' do
    it 'puts a past day in the center' do
      date = Date.new(2026, 1, 15)

      expect(described_class.with_margin(date..date, bounds: nil..today)).to eq(
        Date.new(2026, 1, 1)..Date.new(2026, 1, 29),
      )
    end

    it 'ends today for today' do
      expect(described_class.with_margin(today..today, bounds: nil..today)).to eq((today - 14)..today)
    end

    it 'stays inside the bounds' do
      date = Date.new(2026, 1, 15)
      bounds = Date.new(2026, 1, 10)..Date.new(2026, 1, 20)

      expect(described_class.with_margin(date..date, bounds:)).to eq(bounds)
    end
  end

  describe '.bounds' do
    let(:timeframe) { Timeframe.new('2026') }

    it 'reaches from the installation date to today for a car without a period' do
      expect(described_class.bounds(timeframe, car: Car.new(id: 1))).to eq(timeframe.min_date..today)
    end

    it 'ends at the period of the car' do
      car = Car.new(id: 1, active_from: Date.new(2026, 3, 1), active_until: Date.new(2026, 6, 30))

      expect(described_class.bounds(timeframe, car:)).to eq(Date.new(2026, 3, 1)..Date.new(2026, 6, 30))
    end
  end
end
