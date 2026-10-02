require 'rails_helper'

describe Car::ChargeSplit do
  subject(:split) { described_class.new(ChargingSession.all.to_a) }

  let(:car) { Car.create!(id: 1) }

  before do
    stub_feature(:power_splitter)

    # 2 kWh grid for 0.60 and 8 kWh PV for 0.80
    start = Time.zone.local(2026, 1, 15, 12)
    ChargingSession.create!(kind: :wallbox, car:, started_at: start, ended_at: start + 1.hour, kwh: 10, kwh_grid: 2, cost: 1.4, cost_grid: 0.6)
    ChargingSession.create!(kind: :offsite, car:, started_at: Time.zone.local(2026, 1, 16, 12), kwh: 5, cost: 3)
  end

  it 'splits the charged energy into PV, home grid and offsite' do
    expect(split.energy).to eq(pv: 8_000, grid: 2_000, offsite: 5_000)
  end

  # The detection stores the cost of the grid share, so the split reads no
  # price
  it 'splits the cost by the stored cost of the grid share' do
    cost = split.cost

    expect(cost[:pv]).to be_within(0.001).of(0.8)
    expect(cost[:grid]).to be_within(0.001).of(0.6)
    expect(cost[:offsite]).to eq(3)
  end

  context 'with a wallbox session without the power splitter' do
    before do
      start = Time.zone.local(2026, 1, 17, 12)
      ChargingSession.create!(kind: :wallbox, car:, started_at: start, ended_at: start + 1.hour, kwh: 3)
    end

    it 'gives no split' do
      expect(split).not_to be_split
      expect(split.energy).to be_nil
      expect(split.wallbox_wh).to eq(13_000)
    end
  end
end
