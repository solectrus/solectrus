describe Sensor::Query::Helpers::Influx::DailyCurves do
  subject(:curves) { described_class.new([day], [{ sensor_names: %i[wallbox_power wallbox_car_connected] }]).call[day] }

  let(:day) { Date.new(2026, 6, 10) }

  # A reading at the start of each 5-minute bucket, so each bucket has one
  def write(field, values)
    influx_batch do
      values.each_with_index do |value, index|
        add_influx_point(
          name: Sensor::Config.measurement(:wallbox_power),
          fields: { field => value },
          time: day.in_time_zone.change(hour: 10) + (index * 5).minutes,
        )
      end
    end
  end

  def values(sensor_name) = curves[sensor_name].map(&:last)

  it 'reads a boolean as 0 or 1' do
    write(Sensor::Config.field(:wallbox_car_connected), [true, false])

    expect(values(:wallbox_car_connected)).to eq([1.0, 0.0])
  end

  # A collector that writes text, for example from MQTT. toFloat() failed on
  # such a text for the whole program, also for the curves of other sensors.
  it 'reads a boolean that comes as text, and leaves out a text that is no boolean' do
    write(Sensor::Config.field(:wallbox_car_connected), %w[true False ON unavailable 0])
    write(Sensor::Config.field(:wallbox_power), [500, 0])

    expect(values(:wallbox_car_connected)).to eq([1.0, 0.0, 1.0, 0.0])
    expect(values(:wallbox_power)).to eq([500.0, 0.0])
  end

  # An idle wallbox sends few rows
  context 'with the buckets above 0 alone' do
    subject(:curves) { described_class.new([day], [{ sensor_names: %i[wallbox_power], positive: true }]).call[day] }

    it 'leaves out the buckets of 0' do
      write(Sensor::Config.field(:wallbox_power), [0, 500, 0, 700])

      expect(values(:wallbox_power)).to eq([500.0, 700.0])
    end
  end

  # A collector can write the power as an integer. InfluxDB pins the type of
  # a field, so the integers go to a measurement of their own, without the
  # float conversion of #add_influx_point.
  context 'with a power of integers' do
    subject(:curves) { described_class.new([day], [{ sensor_names: %i[wallbox_power], positive: true }]).call[day] }

    before { Sensor::Config.setup(ENV.to_h.merge('INFLUX_SENSOR_WALLBOX_POWER' => 'IntegerWallbox:power')) }
    after { Sensor::Config.setup(ENV) }

    it 'gives the means as floats' do
      start = day.in_time_zone.change(hour: 10)
      add_influx_points(
        [[0, 400], [1, 501], [5, 0]].map { |minutes, watt| { name: 'IntegerWallbox', fields: { 'power' => watt }, time: (start + minutes.minutes).to_i } },
      )

      expect(values(:wallbox_power)).to eq([450.5])
    end
  end

  # The reading before the day is no mean, so it keeps the type of InfluxDB
  context 'with a state of integers' do
    subject(:curves) { described_class.new([day], [{ sensor_names: %i[car_battery_soc_1], state: true }]).call[day] }

    before { Sensor::Config.setup(ENV.to_h.merge('INFLUX_SENSOR_CAR_BATTERY_SOC' => 'IntegerCar:soc')) }
    after { Sensor::Config.setup(ENV) }

    it 'starts with the reading before the day, as a float like the means' do
      add_influx_points(
        [[day.in_time_zone - 1.hour, 40], [day.in_time_zone.change(hour: 10), 41]].map do |time, soc|
          { name: 'IntegerCar', fields: { 'soc' => soc }, time: time.to_i }
        end,
      )

      expect(values(:car_battery_soc_1)).to eq([40.0, 41.0])
    end
  end

  # One stream reads the run of days, and each day gets the buckets of its
  # window, as if it had a stream of its own
  context 'with a run of days' do
    subject(:result) { described_class.new([day, day + 1], [{ sensor_names: %i[wallbox_power], margin: }]).call }

    let(:margin) { 0 }

    def point(time, value)
      influx_batch do
        add_influx_point(name: Sensor::Config.measurement(:wallbox_power), fields: { Sensor::Config.field(:wallbox_power) => value }, time:)
      end
    end

    def times(date) = result[date][:wallbox_power].map { it.first.in_time_zone.strftime('%d. %H:%M:%S') }

    before do
      point(day.in_time_zone.change(hour: 23, min: 57), 500)
      point((day + 1).in_time_zone.change(hour: 0, min: 2), 600)
    end

    it 'ends the last bucket of a day a second before midnight' do
      expect(times(day)).to eq(['10. 23:59:59'])
      expect(times(day + 1)).to eq(['11. 00:05:00'])
    end

    context 'with a margin' do
      let(:margin) { 1.hour }

      # The window of each day reaches past midnight, so no bucket ends early
      it 'gives the buckets near midnight to both days' do
        expect(times(day)).to eq(['11. 00:00:00', '11. 00:05:00'])
        expect(times(day + 1)).to eq(['11. 00:00:00', '11. 00:05:00'])
      end
    end
  end
end
