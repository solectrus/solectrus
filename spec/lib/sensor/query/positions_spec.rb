describe Sensor::Query::Positions do
  subject(:segments) do
    described_class.new(latitude: :car_latitude_1, longitude: :car_longitude_1, period:).call
  end

  let(:period) { Time.zone.parse('2026-09-22 00:00')..Time.zone.parse('2026-09-22 23:59:59') }

  let(:readings) do
    {
      # Before the period, so the position at its start is known
      Time.zone.parse('2026-09-21 23:00') => home,
      Time.zone.parse('2026-09-22 06:00') => home,
      Time.zone.parse('2026-09-22 08:00') => work,
      Time.zone.parse('2026-09-22 09:00') => work,
    }
  end

  def home = [50.92263, 6.40706]
  def work = [50.90600, 6.40700]

  before do
    Sensor::Config.setup(
      ENV.to_h.merge(
        'INFLUX_SENSOR_CAR_LATITUDE_1' => 'Trabant:latitude',
        'INFLUX_SENSOR_CAR_LONGITUDE_1' => 'Trabant:longitude',
      ),
    )

    influx_batch do
      readings.each do |time, (latitude, longitude)|
        add_influx_point(name: 'Trabant', fields: { 'latitude' => latitude, 'longitude' => longitude }, time:)
      end
    end
  end

  after { Sensor::Config.setup(ENV) }

  # Home from midnight to 08:00. Work from 08:00 until the end of the
  # period, because a position holds until the next reading.
  it 'gives a segment for each change, cut to the period' do
    expect(segments.map { [it.from.strftime('%H:%M'), it.to.strftime('%H:%M'), it.latitude] }).to eq(
      [['00:00', '08:00', home.first], ['08:00', '23:59', work.first]],
    )
  end

  # A source like TeslaMate sends a position only when it changes
  context 'with a car that stood still since days' do
    let(:readings) { { Time.zone.parse('2026-09-18 19:00') => home } }

    it 'gives the whole period at the position of the last reading' do
      expect(segments.map { [it.from, it.to, it.latitude, it.gap] }).to eq([[period.begin, period.end, home.first, nil]])
    end
  end

  # The reading before work was at home at 06:00. The first reading of the
  # query has nothing before it.
  it 'gives the time since the reading before' do
    expect(segments.map(&:gap)).to eq([nil, 2.hours.to_f])
  end

  context 'when the second reading has another position' do
    let(:readings) do
      {
        Time.zone.parse('2026-09-21 23:00') => home,
        Time.zone.parse('2026-09-22 06:00') => work,
      }
    end

    it 'keeps both readings' do
      expect(segments.map { [it.from.strftime('%H:%M'), it.latitude, it.gap] }).to eq(
        [['00:00', home.first, nil], ['06:00', work.first, 7.hours.to_f]],
      )
    end
  end

  # The source of the position stops, but the car drives on
  context 'with an odometer that rises after the last position' do
    subject(:segments) do
      described_class.new(latitude: :car_latitude_1, longitude: :car_longitude_1, odometer: :car_odometer_1, period:).call
    end

    let(:readings) { { Time.zone.parse('2026-09-21 19:00') => home } }

    before do
      Sensor::Config.setup(
        ENV.to_h.merge(
          'INFLUX_SENSOR_CAR_LATITUDE_1' => 'Trabant:latitude',
          'INFLUX_SENSOR_CAR_LONGITUDE_1' => 'Trabant:longitude',
          'INFLUX_SENSOR_CAR_ODOMETER_1' => 'Trabant:mileage',
        ),
      )

      influx_batch do
        { '2026-09-21 19:00' => 1000.0, '2026-09-21 19:01' => 1000.3, '2026-09-22 07:30' => 1012.0 }.each do |time, km|
          add_influx_point(name: 'Trabant', fields: { 'mileage' => km }, time: Time.zone.parse(time))
        end
      end
    end

    # The rise of 0.3 km at 19:01 is the end of the drive home
    it 'ends the position when the car drove away' do
      expect(segments.map { [it.from.strftime('%H:%M'), it.to.strftime('%H:%M')] }).to eq([%w[00:00 07:30]])
    end
  end

  # A parked car repeats its odometer, and the query keeps only its changes
  context 'with an odometer that repeats its value' do
    subject(:segments) do
      described_class.new(latitude: :car_latitude_1, longitude: :car_longitude_1, odometer: :car_odometer_1, period:).call
    end

    let(:readings) { { Time.zone.parse('2026-09-22 06:00') => home } }

    before do
      Sensor::Config.setup(
        ENV.to_h.merge(
          'INFLUX_SENSOR_CAR_LATITUDE_1' => 'Trabant:latitude',
          'INFLUX_SENSOR_CAR_LONGITUDE_1' => 'Trabant:longitude',
          'INFLUX_SENSOR_CAR_ODOMETER_1' => 'Trabant:mileage',
        ),
      )

      influx_batch do
        { '06:00' => 1000.0, '06:30' => 1000.0, '07:00' => 1000.5, '07:15' => 1000.5, '07:30' => 1012.0, '07:45' => 1012.0 }.each do |time, km|
          add_influx_point(name: 'Trabant', fields: { 'mileage' => km }, time: Time.zone.parse("2026-09-22 #{time}"))
        end
      end
    end

    it 'ends the position at the first reading of the rise' do
      expect(segments.map { [it.from.strftime('%H:%M'), it.to.strftime('%H:%M')] }).to eq([%w[06:00 07:30]])
    end
  end

  # A collector can write the odometer as an integer, and Flux compares it
  # with the float of the filter. InfluxDB pins the type of a field, so the
  # integers go to a measurement of their own, without the float conversion
  # of #add_influx_point.
  context 'with an odometer of integers' do
    subject(:segments) do
      described_class.new(latitude: :car_latitude_1, longitude: :car_longitude_1, odometer: :car_odometer_1, period:).call
    end

    let(:readings) { { Time.zone.parse('2026-09-22 06:00') => home } }

    before do
      Sensor::Config.setup(
        ENV.to_h.merge(
          'INFLUX_SENSOR_CAR_LATITUDE_1' => 'Trabant:latitude',
          'INFLUX_SENSOR_CAR_LONGITUDE_1' => 'Trabant:longitude',
          'INFLUX_SENSOR_CAR_ODOMETER_1' => 'IntegerOdometer:km',
        ),
      )

      add_influx_points(
        { '06:00' => 1000, '06:30' => 1000, '07:30' => 1012, '07:45' => 1012 }.map do |time, km|
          { name: 'IntegerOdometer', fields: { 'km' => km }, time: Time.zone.parse("2026-09-22 #{time}").to_i }
        end,
      )
    end

    it 'ends the position at the first reading of the rise' do
      expect(segments.map { [it.from.strftime('%H:%M'), it.to.strftime('%H:%M')] }).to eq([%w[06:00 07:30]])
    end
  end

  context 'with a period that ends before the next reading' do
      let(:period) { Time.zone.parse('2026-09-22 00:00')..Time.zone.parse('2026-09-22 10:00') }

      it 'ends the last segment with the period' do
        expect(segments.last.to).to eq(Time.zone.parse('2026-09-22 10:00'))
      end
  end

  context 'without the longitude' do
    before { Sensor::Config.setup(ENV.to_h.merge('INFLUX_SENSOR_CAR_LATITUDE_1' => 'Trabant:latitude')) }

    it { is_expected.to eq([]) }
  end
end
