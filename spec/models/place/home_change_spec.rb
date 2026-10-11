describe Place::HomeChange do
  subject(:home_change) { described_class.new }

  let(:dates) { Date.new(2026, 9, 18)..Date.new(2026, 9, 22) }
  let(:located) { true }
  let(:period) { { active_from: Date.new(2026, 1, 1) } }

  def add_position(time)
    add_influx_point(
      name: Sensor::Config.measurement(:car_latitude_1),
      fields: { Sensor::Config.field(:car_latitude_1) => 50.92263 },
      time:,
    )
  end

  def summary_dates = Summary.order(:date).pluck(:date)

  before do
    travel_to Date.new(2026, 9, 23).in_time_zone.change(hour: 12)
    location = { 'INFLUX_SENSOR_CAR_LATITUDE_1' => 'Trabant:latitude', 'INFLUX_SENSOR_CAR_LONGITUDE_1' => 'Trabant:longitude' }
    Sensor::Config.setup(
      ENV.to_h.merge('INFLUX_SENSOR_CAR_BATTERY_SOC_1' => 'Trabant:soc', **(located ? location : {})),
    )
    Car.create!(id: 1, **period)
    dates.each { Summary.create!(date: it) }
  end

  after { Sensor::Config.setup(ENV) }

  it 'removes the summaries from the first position of a car' do
    add_position(Time.zone.parse('2026-09-20 10:00'))

    home_change.call

    expect(summary_dates).to eq([Date.new(2026, 9, 18), Date.new(2026, 9, 19)])
  end

  context 'with a car in use since a day after its first position' do
    let(:period) { { active_from: Date.new(2026, 9, 21) } }

    it 'removes the summaries from the first day of use' do
      add_position(Time.zone.parse('2026-08-01 10:00'))

      home_change.call

      expect(summary_dates).to eq(dates.first(3))
    end
  end

  context 'with a car out of use' do
    let(:period) { { active_from: Date.new(2026, 1, 1), active_until: Date.new(2026, 9, 21) } }

    it 'keeps the summaries after the last day of use' do
      add_position(Time.zone.parse('2026-09-20 10:00'))

      home_change.call

      expect(summary_dates).to eq([Date.new(2026, 9, 18), Date.new(2026, 9, 19), Date.new(2026, 9, 22)])
    end
  end

  it 'keeps the summaries of a car without a position' do
    home_change.call

    expect(summary_dates).to eq(dates.to_a)
  end

  context 'without the location of a car' do
    let(:located) { false }

    it 'keeps the summaries without a query' do
      allow(Sensor::Query::FirstSeen).to receive(:new)

      home_change.call

      expect(summary_dates).to eq(dates.to_a)
      expect(Sensor::Query::FirstSeen).not_to have_received(:new)
    end
  end

  it 'builds each day again when InfluxDB cannot tell the first position' do
    allow(Sensor::Query::FirstSeen).to receive(:new).and_raise(StandardError, 'timeout')

    home_change.call

    expect(Summary.count).to eq(0)
  end
end
