describe Sensor::Chart::CarChargingCosts do
  subject(:chart) { described_class.new(timeframe:, cars:) }

  let(:today) { Date.new(2026, 9, 23) }
  let(:car) { Car.create!(id: 1) }
  let(:other_car) { Car.create!(id: 2) }
  let(:cars) { [car, other_car] }

  def wallbox(date, kwh:, kwh_grid:, cost:, car_id: 1, guest: false)
    start = date.in_time_zone.change(hour: 12)
    ChargingSession.create!(kind: :wallbox, car_id:, guest:, started_at: start, ended_at: start + 1.hour, kwh:, kwh_grid:, cost:, cost_grid: (kwh_grid * 0.30 if kwh_grid))
  end

  def column(chart, month)
    index = chart.data[:labels].index { Time.zone.at(it / 1000).month == month }
    chart.data[:datasets].to_h { [it[:id], it[:data][index]] }
  end

  before do
    stub_feature(:car, :power_splitter)
    travel_to today.in_time_zone.change(hour: 12)
    Price.electricity.create!(starts_at: Date.new(2025, 1, 1), value: 0.30)
    Price.feed_in.create!(starts_at: Date.new(2025, 1, 1), value: 0.10)

    # 20 kWh from the grid for 6 EUR, and 20 kWh of PV for 2 EUR
    wallbox(Date.new(2026, 6, 10), kwh: 20, kwh_grid: 20, cost: 6, car_id: car.id)
    wallbox(Date.new(2026, 6, 20), kwh: 20, kwh_grid: 0, cost: 2, car_id: other_car.id)

    # Neither counts for a car
    wallbox(Date.new(2026, 6, 11), kwh: 10, kwh_grid: 10, cost: 3, car_id: nil, guest: true)
    wallbox(Date.new(2026, 6, 12), kwh: 10, kwh_grid: 10, cost: 3, car_id: nil)

    ChargingSession.create!(kind: :offsite, car:, started_at: Time.zone.local(2026, 6, 15, 12), kwh: 5, cost: 4)
  end

  context 'with a year' do
    let(:timeframe) { Timeframe.new('2026') }

    it 'stacks the costs of the sessions of the cars' do
      expect(column(chart, 6)).to eq('wallbox_costs_pv' => 2.0, 'wallbox_costs_grid' => 6.0, 'offsite' => 4.0)
    end

    context 'with one car selected' do
      let(:cars) { [car] }

      it 'shows the sessions of the car' do
        expect(column(chart, 6)).to eq('wallbox_costs_pv' => nil, 'wallbox_costs_grid' => 6.0, 'offsite' => 4.0)
      end
    end
  end

  context 'with a day' do
    let(:timeframe) { Timeframe.new('2026-06-10') }

    it 'shows the cost of the wallbox' do
      expect(chart.chart_sensor_names).to eq(%i[wallbox_costs_pv wallbox_costs_grid])
    end
  end

  describe Sensor::Chart::CarCharging do
    subject(:chart) { described_class.new(timeframe: Timeframe.new('2026'), cars:) }

    it 'stacks the energy of the sessions of the cars' do
      expect(column(chart, 6)).to eq('wallbox_power_pv' => 20_000.0, 'wallbox_power_grid' => 20_000.0, 'offsite' => 5_000.0)
    end

    context 'with a session without the power splitter' do
      before do
        wallbox(Date.new(2026, 6, 21), kwh: 3, kwh_grid: nil, cost: 1, car_id: car.id)
      end

      it 'shows the energy of the wallbox in one part' do
        expect(column(chart, 6)).to eq('wallbox_power' => 43_000.0, 'offsite' => 5_000.0)
      end
    end
  end
end
