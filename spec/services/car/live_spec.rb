describe Car::Live do
  subject(:live) { described_class.new(cars, home:) }

  let(:cars) { [Car.create!(id: 1), Car.create!(id: 2)] }
  let(:home) { nil }
  let(:data) do
    Sensor::Data::Single.new(
      { car_battery_soc_1: 80, car_range_1: 300, car_max_range_1: 375, car_odometer_1: 12_345, car_connected_1: true, car_latitude_1: 50.9, car_longitude_1: 6.4, car_battery_soc_2: 40, wallbox_power: 11_000 },
      timeframe: Timeframe.now,
    )
  end

  before do
    allow(Sensor::Query::Latest).to receive(:new).and_return(instance_double(Sensor::Query::Latest, call: data))
  end

  it 'gives the state of each car' do
    expect(live.states.map(&:to_h)).to eq(
      [
        { car: cars.first, soc: 80, range: 300, max_range: 375, odometer: 12_345, connected: true, charging_power: 11_000, latitude: 50.9, longitude: 6.4, time: nil },
        { car: cars.last, soc: 40, range: nil, max_range: nil, odometer: nil, connected: nil, charging_power: nil, latitude: nil, longitude: nil, time: nil },
      ],
    )
  end

  it 'gives no state of a car outside its period' do
    cars.first.update!(active_until: Date.yesterday)

    expect(live.states.first.to_h).to eq(
      car: cars.first, soc: nil, range: nil, max_range: nil, odometer: nil, connected: nil, charging_power: nil, latitude: nil, longitude: nil, time: nil,
    )
  end

  # A car sensor holds its state at any age, so the time tells how old it is
  context 'with the times of the readings' do
    let(:data) do
      Sensor::Data::Single.new(
        { car_battery_soc_1: 80, car_odometer_1: 12_345 },
        timeframe: Timeframe.now,
        times: { car_battery_soc_1: Time.zone.local(2026, 10, 7, 12), car_odometer_1: Time.zone.local(2026, 10, 5, 18) },
      )
    end

    it 'gives the latest reading of each car' do
      expect(live.states.map(&:time)).to eq([Time.zone.local(2026, 10, 7, 12), nil])
    end
  end

  # The source of the position stopped, but the car drove on
  context 'with an odometer that rose since the latest position' do
    let(:data) do
      Sensor::Data::Single.new(
        { car_odometer_1: 12_345, car_latitude_1: 50.9, car_longitude_1: 6.4 },
        timeframe: Timeframe.now,
        times: { car_odometer_1: 1.hour.ago, car_latitude_1: 2.days.ago, car_longitude_1: 2.days.ago },
      )
    end

    before do
      allow(Sensor::Query::LastSeen).to receive(:new).and_return(instance_double(Sensor::Query::LastSeen, readings: { car_odometer_1: odometer }))
    end

    context 'when the car drove away' do
      let(:odometer) { 12_300 }

      it 'gives no location' do
        expect(live.states.first.location).to be_nil
      end
    end

    context 'when the car moved less than a kilometer' do
      let(:odometer) { 12_344.5 }

      it 'keeps the location' do
        expect(live.states.first.location).to eq([50.9, 6.4])
      end
    end
  end

  it 'gives the location of a car with both coordinates' do
      expect(live.states.map(&:location)).to eq([[50.9, 6.4], nil])
  end

  it 'gives the power of the wallbox' do
    expect(live.wallbox_power).to eq(11_000)
  end

  it 'gives the charging power to the one car that reports a connection' do
    expect(live.states.map(&:charging_power)).to eq([11_000, nil])
  end

  it 'knows the car at the wallbox' do
    expect(live).to be_car_at_wallbox
  end

  context 'with home' do
    let(:cars) { [Car.create!(id: 1)] }
    let(:home) { Place.new(latitude: 50.9, longitude: 6.4) }
    let(:data) do
      Sensor::Data::Single.new(
        { car_connected_1: true, car_latitude_1: latitude, car_longitude_1: 6.4, wallbox_power: 11_000, wallbox_car_connected: wallbox_connected },
        timeframe: Timeframe.now,
      )
    end
    let(:latitude) { 50.9 }
    let(:wallbox_connected) { true }

    it 'gives the charging power to the connected car at home' do
      expect(live.states.first.charging_power).to eq(11_000)
    end

    context 'when the car is away' do
      let(:latitude) { 51.0 }

      it 'gives the car zero next to its plug' do
        expect(live.states.first.charging_power).to eq(0)
        expect(live).not_to be_car_at_wallbox
      end
    end

    context 'when the wallbox reports no connection' do
      let(:wallbox_connected) { false }

      it 'gives the car zero next to its plug' do
        expect(live.states.first.charging_power).to eq(0)
        expect(live).not_to be_car_at_wallbox
      end
    end
  end

  context 'when no car reports a connection' do
    let(:data) do
      Sensor::Data::Single.new({ car_connected_1: false, car_connected_2: false, wallbox_power: 11_000 }, timeframe: Timeframe.now)
    end

    it 'gives each car zero next to its plug' do
      expect(live.states.map(&:charging_power)).to eq([0, 0])
      expect(live).not_to be_car_at_wallbox
    end
  end

  context 'when the other car reports no connection' do
    let(:data) do
      Sensor::Data::Single.new({ car_connected_1: true, car_connected_2: false, wallbox_power: 11_000 }, timeframe: Timeframe.now)
    end

    it 'gives the other car zero next to its plug' do
      expect(live.states.map(&:charging_power)).to eq([11_000, 0])
    end
  end

  # The car sends no new reading for a long time, for example when it sleeps
  context 'when the plug of the car contradicts the plug of the wallbox' do
    let(:cars) { [Car.create!(id: 1)] }
    let(:data) do
      Sensor::Data::Single.new(
        { car_connected_1: !wallbox_connected, wallbox_power: 11_000, wallbox_car_connected: wallbox_connected },
        timeframe: Timeframe.now,
        times: { car_connected_1: 1.day.ago },
      )
    end
    let(:wallbox_connected) { true }

    before do
      allow(Sensor::Query::ChangedSince).to receive(:new).and_return(instance_double(Sensor::Query::ChangedSince, call: changed))
    end

    context 'when the wallbox changed since the reading of the car' do
      let(:changed) { true }

      it 'gives the car the charging power and the plug of the wallbox' do
        expect(live.states.first).to have_attributes(charging_power: 11_000, connected: true)
        expect(live).to be_car_at_wallbox
        expect(Sensor::Query::ChangedSince).to have_received(:new).with(:wallbox_car_connected, since: data.time_for(:car_connected_1))
      end

      context 'when the wallbox was unplugged' do
        let(:wallbox_connected) { false }

        it 'gives the car the plug of the wallbox' do
          expect(live.states.first).to have_attributes(charging_power: 0, connected: false)
        end
      end
    end

    context 'when the wallbox did not change since the reading of the car' do
      let(:changed) { false }

      it 'gives the car zero next to its plug' do
        expect(live.states.first).to have_attributes(charging_power: 0, connected: false)
        expect(live).not_to be_car_at_wallbox
      end

      # For example a car at a public charger
      context 'when the wallbox is unplugged' do
        let(:wallbox_connected) { false }

        it 'keeps the plug of the car' do
          expect(live.states.first).to have_attributes(connected: true)
        end
      end
    end
  end

  context 'when the plug of the car agrees with the plug of the wallbox' do
    let(:data) do
      Sensor::Data::Single.new(
        { car_connected_1: true, wallbox_car_connected: true },
        timeframe: Timeframe.now,
        times: { car_connected_1: 1.day.ago },
      )
    end

    it 'asks for no change of the wallbox' do
      allow(Sensor::Query::ChangedSince).to receive(:new)
      live.states

      expect(Sensor::Query::ChangedSince).not_to have_received(:new)
    end
  end

  context 'with two cars without a sign' do
    let(:data) do
      Sensor::Data::Single.new({ wallbox_power: 11_000 }, timeframe: Timeframe.now)
    end

    it 'gives the power of the wallbox to no car' do
      expect(live.states.map(&:charging_power)).to eq([nil, nil])
      expect(live).not_to be_car_at_wallbox
    end
  end

  context 'with one car in use' do
    let(:data) do
      Sensor::Data::Single.new({ wallbox_power: 11_000, wallbox_car_connected: true }, timeframe: Timeframe.now)
    end

    before { cars.last.update!(active_until: Date.yesterday) }

    it 'gives this car the charging power and the plug of the wallbox' do
      expect(live.states.first).to have_attributes(charging_power: 11_000, connected: true)
      expect(live.states.last).to have_attributes(charging_power: nil, connected: nil)
    end
  end
end
