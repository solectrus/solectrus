describe McpServer::Tools::CarCosts do
  def wallbox(day, kwh:, **attributes)
    start = Time.zone.local(2026, 1, day, 12)
    ChargingSession.create!(kind: :wallbox, origin: :detection, started_at: start, ended_at: start + 1.hour, kwh:, **attributes)
  end

  # Each day the report of January reads, so nothing is missing
  def summarize_reach
    Summary.insert_all!(Car::Report.reach(Timeframe.new('2026-01')).map { { date: it, created_at: Time.current, updated_at: Time.current } })
  end

  def call(**)
    response = described_class.call(**)
    [response.error?, JSON.parse(response.content.first[:text], symbolize_names: true)]
  end

  before do
    travel_to Time.zone.local(2026, 9, 23, 12)
    Car.create!(id: 1, name: 'Testcar')
    summarize_reach

    SummaryValue.create!(date: Date.new(2026, 1, 1), field: 'car_odometer_1', aggregation: 'sum', value: 0)
    SummaryValue.create!(date: Date.new(2026, 1, 10), field: 'car_odometer_1', aggregation: 'sum', value: 120)

    wallbox(10, kwh: 10, kwh_grid: 4, cost: 1.6, cost_grid: 1.2, car_id: 1)
    wallbox(12, kwh: 5, kwh_grid: 1, guest: true, cost: 1.5, cost_grid: 0.5)
    wallbox(13, kwh: 7, kwh_grid: 2)
    ChargingSession.create!(kind: :offsite, origin: :user, car_id: 1, started_at: Time.zone.local(2026, 1, 14, 12), kwh: 8, cost: 4.0)
  end

  it 'is available with a car' do
    expect(described_class.available?).to be(true)
  end

  context 'with one car' do
    it 'returns the figures of the car' do
      error, data = call(timeframe: '2026-01', car: 1)

      expect(error).to be(false)
      expect(data).to include(
        timeframe: '2026-01',
        cars: [{ number: 1, name: 'Testcar' }],
        distance_km: 120,
        charging: {
          energy_wh: 18_000,
          cost: 5.6,
          sources: {
            pv: { energy_wh: 6000, cost: 0.4 },
            grid: { energy_wh: 4000, cost: 1.2 },
            offsite: { energy_wh: 8000, cost: 4.0 },
          },
        },
        driving: {
          energy_wh: 18_000,
          cost: 5.6,
          kwh_per_100km: 15.0,
          cost_per_100km: 4.67,
        },
      )
      expect(data).not_to include(:guest_charging, :unassigned_charging)
    end
  end

  context 'with all cars' do
    it 'counts the guests and names the sessions of no car' do
      error, data = call(timeframe: '2026-01')

      expect(error).to be(false)
      expect(data[:charging]).to include(energy_wh: 23_000, cost: 7.1)
      expect(data[:guest_charging]).to eq(energy_wh: 5000, cost: 1.5)
      expect(data[:unassigned_charging]).to eq(energy_wh: 7000, cost: nil)
    end
  end

  context 'with sessions without a price' do
    before { wallbox(20, kwh: 3, kwh_grid: 1, car_id: 1) }

    it 'counts them' do
      _, data = call(timeframe: '2026-01', car: 1)

      expect(data[:charging]).to include(energy_wh: 21_000, cost: 5.6, uncosted_sessions: 1)
    end
  end

  context 'with a few missing summaries' do
    before { Summary.where(date: [Date.new(2025, 12, 31), Date.new(2026, 2, 3), Date.current]).delete_all }

    it 'builds them and answers' do
      error = nil
      expect { error, = call(timeframe: '2026-01', car: 1) }.to change(Summary, :count).by(3)

      expect(error).to be(false)
    end

    it 'leaves a day alone that the timeframe does not read' do
      days = (Date.new(2024, 11, 1)..Date.new(2026, 2, 28)).to_a - Summary.pluck(:date) - [Date.new(2025, 12, 31), Date.new(2026, 2, 3)]
      Summary.insert_all!(days.map { { date: it, created_at: Time.current, updated_at: Time.current } })

      expect { call(timeframe: '2025-06', car: 1) }.to change(Summary, :count).by(2)
      expect(Summary.exists?(Date.current)).to be(false)
    end
  end

  context 'with more missing summaries than one call builds' do
    before { Summary.where(date: Date.new(2026, 3, 1)..Date.new(2026, 4, 1)).delete_all }

    it 'stops, names the days and builds none' do
      response = nil
      expect { response = described_class.call(timeframe: '2026-01') }.not_to change(Summary, :count)

      expect(response.error?).to be(true)
      expect(response.content.first[:text]).to include('32 days from 2026-03-01 to 2026-04-01 have no summary yet')
    end
  end

  context 'with a stale summary' do
    let(:date) { Date.new(2026, 1, 20) }

    before { Summary.where(date:).update_all(updated_at: date.beginning_of_day) } # rubocop:disable Rails/SkipsModelValidations

    it 'builds it again and answers' do
      error = nil
      expect { error, = call(timeframe: '2026-01', car: 1) }.to(change { Summary.find(date).updated_at })

      expect(error).to be(false)
    end
  end

  # The note of get_totals speaks of an aggregation per entry, which this
  # tool has none of
  it 'says that the sums of a running period are cut short and the rates are not' do
    _, data = call(timeframe: '2026-09', car: 1)

    expect(data[:timeframe_note]).to include('sums cover it only up to now', 'rates per 100 km and km_per_day are not cut short')
    expect(data[:timeframe_note]).not_to include('aggregation')
  end

  it 'does not point a future period to get_forecast' do
    _, data = call(timeframe: '2027', car: 1)

    expect(data[:timeframe_note]).to include('in the future')
    expect(data[:timeframe_note]).not_to include('get_forecast')
  end

  # null means a missing price, and nothing charged has none missing
  it 'costs 0 without a session' do
    _, data = call(timeframe: '2026-01-25', car: 1)

    expect(data[:charging]).to include(energy_wh: 0, cost: 0.0)
    expect(data[:charging][:sources].values).to all(include(cost: 0.0))
  end

  it 'says nothing for a period that has ended' do
    _, data = call(timeframe: '2026-01', car: 1)

    expect(data).not_to have_key(:timeframe_note)
  end

  describe 'the comparison with a combustion car' do
    let(:fuel_prices) { instance_double(Car::FuelPrices, any?: true) }

    before do
      allow(Car::FuelPrices).to receive(:new).and_call_original
      allow(Car::FuelPrices).to receive(:new).with('petrol').and_return(fuel_prices)
      allow(fuel_prices).to receive(:at) { |date| 2.0 if date >= Date.new(2026, 1, 1) }
      Car.find(1).update!(fuel_type: 'petrol', fuel_consumption: 8, combustion_tax: 365)
    end

    it 'compares the same distance' do
      _, data = call(timeframe: '2026-01', car: 1)
      comparison = data[:comparison]

      expect(comparison).to include(distance_km: 120)
      expect(comparison[:combustion]).to include(fuel_cost: 19.2)
      expect(comparison[:car]).to include(energy_cost: 5.6)
      expect(comparison[:savings]).to eq((comparison[:combustion][:total] - comparison[:car][:total]).round(2))
    end

    it 'names a car without a combustion car' do
      Car.find(1).update!(fuel_type: nil)
      _, data = call(timeframe: '2026-01', car: 1)

      expect(data).not_to have_key(:comparison)
      expect(data[:comparison_note]).to include('car 1 (Testcar) has no fuel')
    end

    it 'says nothing without fuel prices' do
      allow(Car::Comparison).to receive(:available?).and_return(false)
      _, data = call(timeframe: '2026-01', car: 1)

      expect(data).not_to include(:comparison, :comparison_note)
    end

    it 'names the gaps' do
      _, data = call(timeframe: '2026-01', car: 1)

      expect(data[:comparison][:gaps]).to include(a_string_including('No payment of the cars'))
    end
  end

  it 'rejects a timeframe of hours' do
    response = described_class.call(timeframe: 'P24H')

    expect(response.error?).to be(true)
    expect(response.content.first[:text]).to include('kept per day')
  end

  it 'rejects an unknown car and names the cars' do
    response = described_class.call(timeframe: '2026-01', car: 3)

    expect(response.error?).to be(true)
    expect(response.content.first[:text]).to include('Unknown car 3. This instance has: 1 (Testcar).')
  end
end
