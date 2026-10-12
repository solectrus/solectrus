describe Sensor::Chart::CarSessions do
  subject(:chart) { Sensor::Registry[:car_charging_costs].chart(timeframe, cars:) }

  let(:today) { Date.new(2026, 9, 23) }
  let(:car) { Car.create!(id: 1) }
  let(:other_car) { Car.create!(id: 2) }
  let(:cars) { [car, other_car] }

  def wallbox(date, kwh:, kwh_grid:, cost:, car_id: 1, guest: false)
    start = date.in_time_zone.change(hour: 12)
    ChargingSession.create!(kind: :wallbox, origin: :detection, car_id:, guest:, started_at: start, ended_at: start + 1.hour, kwh:, kwh_grid:, cost:, cost_grid: (kwh_grid * 0.30 if kwh_grid && cost))
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

    ChargingSession.create!(kind: :offsite, origin: :user, car:, started_at: Time.zone.local(2026, 6, 15, 12), kwh: 5, cost: 4)
  end

  context 'with a year' do
    let(:timeframe) { Timeframe.new('2026') }

    it 'stacks the costs of the sessions of all cars by source' do
      expect(column(chart, 6)).to eq('wallbox_costs_pv' => 2.0, 'wallbox_costs_grid' => 6.0, 'offsite' => 4.0)
      expect(chart.data[:datasets].pluck(:summed)).to all(be(true))
    end

    # The first column starts on the installation date, not on the first day
    # of its month
    context 'with an installation in the middle of a month' do
      let(:timeframe) { Timeframe.new('2026', min_date: Date.new(2026, 6, 5)) }

      it 'shows the sessions of the first column' do
        expect(column(chart, 6)).to eq('wallbox_costs_pv' => 2.0, 'wallbox_costs_grid' => 6.0, 'offsite' => 4.0)
      end
    end

    context 'with one car selected' do
      let(:cars) { [car] }

      it 'stacks the costs of the sessions of the car by source' do
        expect(column(chart, 6)).to eq('wallbox_costs_pv' => nil, 'wallbox_costs_grid' => 6.0, 'offsite' => 4.0)
      end
    end
  end

  context 'with a week without a session' do
    let(:timeframe) { Timeframe.new('2026-W30') }

    it 'is blank and shows a plug instead of a message' do
      expect(chart).to be_blank
      expect(chart.blank_message).to eq(I18n.t('data.car_no_charging'))
      expect(chart.blank_icon).to eq('plug')
    end
  end

  # The car charged, but no day of its sessions has a price
  context 'with a week whose sessions have no price' do
    let(:timeframe) { Timeframe.new('2026-W31') }

    before { wallbox(Date.new(2026, 7, 28), kwh: 20, kwh_grid: 20, cost: nil, car_id: car.id) }

    it 'is blank and names the missing price instead of a missing charge' do
      expect(chart).to be_blank
      expect(chart.blank_message).to eq(I18n.t('data.car_no_charging_cost'))
      expect(chart.blank_icon).to be_nil
    end
  end

  context 'with a column with a session without a price' do
    let(:timeframe) { Timeframe.new('2026') }

    before { wallbox(Date.new(2026, 6, 25), kwh: 20, kwh_grid: 20, cost: nil, car_id: car.id) }

    it 'notes on each part of the column that its cost is too small' do
      index = chart.data[:labels].index { Time.zone.at(it / 1000).month == 6 }
      notes = chart.data[:datasets].map { it[:tooltipNotes][index] }

      expect(notes.uniq).to eq([[I18n.t('charging_sessions.cost_incomplete')]])
      expect(chart.data[:datasets].first[:tooltipNotes][index - 1]).to be_nil
    end
  end

  it 'gives no notes when each session has a cost' do
    chart = Sensor::Registry[:car_charging_costs].chart(Timeframe.new('2026'), cars:)

    expect(chart.data[:datasets].pluck(:tooltipNotes)).to all(be_nil)
  end

  context 'with a day' do
    let(:timeframe) { Timeframe.new('2026-06-10') }

    it 'shows the cost of the wallbox' do
      expect(chart.chart_sensor_names).to eq(%i[wallbox_costs_pv wallbox_costs_grid])
    end
  end

  describe 'the charged energy' do
    subject(:chart) { Sensor::Registry[:car_charging].chart(Timeframe.new('2026'), cars:) }

    it 'stacks the energy of the sessions of all cars by source' do
      expect(column(chart, 6)).to eq('wallbox_power_pv' => 20_000.0, 'wallbox_power_grid' => 20_000.0, 'offsite' => 5_000.0)
    end

    context 'with one car selected' do
      let(:cars) { [other_car] }

      it 'stacks the energy of the sessions of the car by source' do
        expect(column(chart, 6)).to eq('wallbox_power_pv' => 20_000.0, 'wallbox_power_grid' => nil, 'offsite' => nil)
      end

      context 'with a session without the power splitter' do
        before do
          wallbox(Date.new(2026, 6, 21), kwh: 3, kwh_grid: nil, cost: 1, car_id: other_car.id)
        end

        it 'shows the energy of the wallbox in one part' do
          expect(column(chart, 6)).to eq('wallbox_power' => 23_000.0, 'offsite' => nil)
        end
      end
    end
  end
end
