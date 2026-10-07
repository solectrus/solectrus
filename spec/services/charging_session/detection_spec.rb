describe ChargingSession::Detection do
  subject(:detection) { described_class.new([day]) }

  let(:day) { Date.new(2026, 6, 10) }

  # One point each minute of the day, like a collector that writes zeros
  # while the wallbox is idle
  def write_day(power:, grid: ->(_watt) { 0 }, connected: ->(_time) { false })
    influx_batch do
      (0...(24 * 60)).each do |minute|
        time = day.in_time_zone + minute.minutes
        watt = power.call(time)
        add_influx_point(
          name: Sensor::Config.measurement(:wallbox_power),
          fields: {
            Sensor::Config.field(:wallbox_power) => watt,
            Sensor::Config.field(:wallbox_car_connected) => connected.call(time) ? 1 : 0,
          },
          time:,
        )
        add_influx_point(
          name: Sensor::Config.measurement(:wallbox_power_grid),
          fields: { Sensor::Config.field(:wallbox_power_grid) => grid.call(watt) },
          time:,
        )
      end
    end
  end

  def between?(time, from, to)
    time >= day.in_time_zone.change(hour: from.first, min: from[1]) &&
      time < day.in_time_zone.change(hour: to.first, min: to[1])
  end

  def sessions = detection.call[day]

  before do
    Price.electricity.create!(starts_at: day - 1.year, value: 0.30)
    Price.feed_in.create!(starts_at: day - 1.year, value: 0.10)

    write_day(
      power:
        lambda do |time|
          if between?(time, [8, 0], [8, 30]) || between?(time, [8, 40], [9, 0])
            11_000 # a gap of 10 minutes does not end the session
          elsif between?(time, [13, 0], [13, 30]) || between?(time, [14, 30], [15, 0])
            3_600 # the car stays connected in the pause of an hour
          elsif between?(time, [20, 0], [20, 30]) || between?(time, [21, 30], [22, 0])
            6_000 # without a connection, the pause ends the session
          elsif between?(time, [23, 0], [23, 30])
            50 # the standby power of the wallbox
          else
            0
          end
        end,
      grid: ->(watt) { watt / 4 },
      connected: ->(time) { between?(time, [12, 55], [15, 5]) },
    )
  end

  it 'finds each session of the day' do
    expect(sessions.map { [it.started_at.in_time_zone.strftime('%H:%M'), it.ended_at.in_time_zone.strftime('%H:%M')] })
      .to eq([%w[08:00 09:00], %w[13:00 15:00], %w[20:00 20:30], %w[21:30 22:00]])
  end

  it 'takes the energy and the grid share from the integral of the raw series' do
    first = sessions.first

    # 50 minutes at 11 kW
    expect(first.kwh).to be_within(0.25).of(9.17)
    expect(first.kwh_grid).to be_within(0.1).of(first.kwh / 4)
  end

  it 'costs the grid share at the electricity price and the PV share at the feed-in price' do
    first = sessions.first

    expect(first.cost).to be_within(0.01).of(((first.kwh_grid * 0.30) + ((first.kwh - first.kwh_grid) * 0.10)).round(2))
    expect(first.cost_grid).to be_within(0.01).of((first.kwh_grid * 0.30).round(2))
  end

  it 'gives each session the one car' do
    expect(sessions.map(&:car_id).uniq).to eq([1])
  end

  # The sessions nearly hold the wallbox energy of the day, and never more.
  # The difference is the idle time: the standby power and what integral gives
  # to the edges, because it connects two points with a straight line.
  it 'holds the wallbox energy of the day' do
    day_wh =
      Sensor::Query::Helpers::Influx::Integral.new(%i[wallbox_power], Timeframe.new(day.iso8601)).call.wallbox_power
    sessions_wh = sessions.sum(&:kwh) * 1000

    expect(sessions_wh).to be <= day_wh
    expect(day_wh - sessions_wh).to be < 500
  end

  context 'without a price' do
    before { Price.delete_all }

    it 'has no cost, because zero is a wrong number' do
      expect(sessions.map(&:cost).uniq).to eq([nil])
    end
  end

  describe '#persist' do
    it 'writes each session as a wallbox session' do
      detection.persist(detection.call)

      expect(ChargingSession.wallbox.count).to eq(4)
    end

    it 'writes the sessions again without a duplicate' do
      2.times { described_class.new([day]).then { it.persist(it.call) } }

      expect(ChargingSession.wallbox.count).to eq(4)
    end
  end

  context 'without a wallbox' do
    before do
      allow(Sensor::Config).to receive(:configured?).and_call_original
      allow(Sensor::Config).to receive(:configured?).with(:wallbox_power).and_return(false)
    end

    it 'finds nothing' do
      expect(sessions).to be_empty
    end
  end
end
