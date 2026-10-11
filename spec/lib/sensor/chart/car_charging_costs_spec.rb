describe Sensor::Chart::CarChargingCosts do
  subject(:chart) { described_class.new(timeframe:, cars:, guest:) }

  let(:car) { Car.create!(id: 1, active_from: Date.new(2026, 1, 1)) }
  let(:cars) { [car] }
  let(:guest) { false }
  let(:timeframe) { Timeframe.new('2026-06-15') }

  def at(hour, minute = 0) = Time.zone.local(2026, 6, 15, hour, minute)

  def wallbox(from, to, **)
    ChargingSession.create!(kind: :wallbox, origin: :detection, started_at: from, ended_at: to, kwh: 1, **)
  end

  # The grid cost of the bucket that ends at the time
  def grid_cost_at(time)
    data = chart.data[:datasets].find { it[:id] == 'wallbox_costs_grid' }[:data]
    data[chart.data[:labels].index(time.to_i * 1000)]
  end

  before do
    travel_to Time.zone.local(2026, 9, 23, 12)
    stub_feature(:car, :power_splitter)

    power = { wallbox_power: 7_000.0, wallbox_power_grid: 4_000.0 }
    influx_batch do
      [at(10, 2), at(12, 2), at(14, 2)].each do |time|
        power.each do |sensor, value|
          add_influx_point(name: Sensor::Config.measurement(sensor), fields: { Sensor::Config.field(sensor) => value }, time:)
        end
      end
    end

    allow(Price).to receive(:at).with(hash_including(name: :electricity)).and_return(BigDecimal('0.4'))
    allow(Price).to receive(:at).with(hash_including(name: :feed_in)).and_return(BigDecimal('0.1'))

    wallbox(at(10), at(10, 5), car:)
    wallbox(at(12), at(12, 5), guest: true)
  end

  it 'stacks the PV and the grid share of the wallbox' do
    expect(chart.data[:datasets]).to match([hash_including(id: 'wallbox_costs_pv'), hash_including(id: 'wallbox_costs_grid')])
  end

  it 'draws the cost of the car and a charge without a session, and leaves out the guest' do
    expect(grid_cost_at(at(10, 5))).to be_positive
    expect(grid_cost_at(at(14, 5))).to be_positive
    expect(grid_cost_at(at(12, 5))).to eq(0)
  end

  context 'with an offsite session from 15:00 to 16:00' do
    before do
      ChargingSession.create!(kind: :offsite, origin: :user, car:, started_at: at(15), ended_at: at(16), kwh: 11, cost: 4.4)
    end

    def offsite_cost_at(time)
      data = chart.data[:datasets].find { it[:id] == 'offsite' }[:data]
      data[chart.data[:labels].index(time.to_i * 1000)]
    end

    it 'stacks its cost per hour on the wallbox' do
      expect(chart.data[:datasets].last).to include(id: 'offsite', fill: '-1', colorClass: 'bg-sensor-offsite', stack: 'CarChargingCosts', summed: true)
      expect([offsite_cost_at(at(15)), offsite_cost_at(at(15, 5)), offsite_cost_at(at(16, 5))]).to eq([0, 4.4, 0])
    end

    context 'with the guest' do
      let(:cars) { [] }
      let(:guest) { true }

      it 'has no offsite session' do
        expect(chart.data[:datasets]).not_to include(hash_including(id: 'offsite'))
      end
    end
  end

  context 'with the guest' do
    let(:cars) { [] }
    let(:guest) { true }

    it 'draws the cost of the guest alone' do
      expect([grid_cost_at(at(10, 5)), grid_cost_at(at(12, 5))]).to match([0, be_positive])
    end
  end
end
