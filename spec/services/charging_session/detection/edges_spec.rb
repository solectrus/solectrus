describe ChargingSession::Detection::Edges do
  subject(:edges) { described_class.new([[at(10), at(10, 30)]]).call[[at(10), at(10, 30)]] }

  def at(hour, minute = 0, second = 0) = Time.zone.local(2026, 6, 10, hour, minute, second)

  def write(readings)
    influx_batch do
      readings.each do |time, watt|
        add_influx_point(name: Sensor::Config.measurement(:wallbox_power), fields: { Sensor::Config.field(:wallbox_power) => watt }, time:)
      end
    end
  end

  it 'starts at the first reading with power and ends at the first reading without power after it' do
    write([[at(10), 0], [at(10, 2, 10), 0], [at(10, 2, 30), 3000], [at(10, 27), 3000], [at(10, 27, 40), 0], [at(10, 29), 0]])

    expect(edges).to eq([at(10, 2, 30), at(10, 27, 40)])
  end

  # A collector that writes a change alone, so the power can stand still
  # without a reading
  it 'ends at the end of the bucket without a reading after the last one with power' do
    write([[at(10, 1), 3000], [at(10, 26), 2000]])

    expect(edges).to eq([at(10, 1), at(10, 30)])
  end

  # The period reaches across a gap of the collector to the bucket after it,
  # which reads no power anymore
  it 'ends at the first reading of a last bucket without power' do
    write([[at(10, 1), 3000], [at(10, 26), 0], [at(10, 28), 0]])

    expect(edges).to eq([at(10, 1), at(10, 26)])
  end

  context 'with a period at midnight' do
    subject(:edges) { described_class.new([[midnight, midnight + 30.minutes]]).call[[midnight, midnight + 30.minutes]] }

    let(:midnight) { at(0) }

    # The detection cuts the charge at midnight into two sessions
    it 'keeps the start of the day for a charge from the day before' do
      write([[midnight - 2.minutes, 3000], [midnight + 3.seconds, 3000]])

      expect(edges.first).to eq(midnight)
    end

    # Like with the tariff of the night
    it 'starts a charge after midnight at its reading' do
      write([[midnight - 2.minutes, 0], [midnight + 40.seconds, 3000]])

      expect(edges.first).to eq(midnight + 40.seconds)
    end
  end

  # The last bucket holds no reading, like across a gap of the collector
  it 'keeps the edge of a bucket without readings' do
    write([[at(10, 1), 3000]])

    expect(edges).to eq([at(10, 1), at(10, 30)])
  end
end
