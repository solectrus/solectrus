describe McpServer::Tools::ListMeasurements do
  let(:now) { Time.zone.local(2026, 1, 11, 6) }

  before { travel_to now }

  def write(name, fields, tags: nil, time: now - 1.hour)
    add_influx_points([{ name:, tags:, fields:, time: time.to_i }])
  end

  def call(**args)
    response = described_class.call(**args)
    text = response.content.first[:text]

    response.error? ? [true, text] : [false, JSON.parse(text, symbolize_names: true)]
  end

  def answer(**args)
    error, data = call(**args)
    expect(error).to be(false), "Unexpected error: #{data}"

    data
  end

  describe 'the measurements' do
    before do
      write('RAW_DEVICE', { level: 1.0 })
      write('RAW_OTHER', { value: 1.0 })
      write('RAW_OLD', { value: 1.0 }, time: now - 40.days)
    end

    it 'lists the ones written within the lookback' do
      data = answer

      expect(data[:measurements]).to include('RAW_DEVICE', 'RAW_OTHER')
      expect(data[:measurements]).not_to include('RAW_OLD')
      expect(data).to include(lookback_days: 30, measurement_count: data[:measurements].size)
    end

    it 'reaches further back on request' do
      expect(answer(lookback_days: 60)[:measurements]).to include('RAW_OLD')
    end

    it 'narrows them by a part of the name, in any case' do
      expect(answer(query: 'raw_')[:measurements]).to eq(%w[RAW_DEVICE RAW_OTHER])
    end

    # The next call would ask for them anyway
    it 'gives the fields of the one measurement a query matches' do
      data = answer(query: 'device')

      expect(data).to include(measurement: 'RAW_DEVICE', series_count: 1)
      expect(data[:fields].keys).to eq([:level])
    end

    it 'finds a measurement by the name of a field' do
      data = answer(query: 'VALU')

      expect(data).to include(measurement: 'RAW_OTHER')
      expect(data[:fields].keys).to eq([:value])
    end

    it 'names the fields that matched in several measurements' do
      write('RAW_THIRD', { value: 2.0 })

      data = answer(query: 'value')

      expect(data).to include(measurements: %w[RAW_OTHER RAW_THIRD], matching_fields: { RAW_OTHER: ['value'], RAW_THIRD: ['value'] })
    end

    it 'gives every name when nothing holds the query, so the model can choose' do
      data = answer(query: 'gas')

      expect(data[:measurements]).to include('RAW_DEVICE', 'RAW_OTHER')
      expect(data[:note]).to include('"gas"', 'not after its brand', 'say so')
    end

    it 'says where it cuts the list' do
      stub_const("#{described_class}::MAX_MEASUREMENTS", 1)

      data = answer(query: 'raw_')

      expect(data).to include(measurement_count: 2, measurements: ['RAW_DEVICE'])
      expect(data[:truncated_note]).to include('1 of 2', '`query`')
    end
  end

  describe 'one measurement' do
    before do
      write('RAW_DEVICE', { level: 12.300000190734863, active: false }, tags: { unit: 'a' }, time: now - 2.hours)
      write('RAW_DEVICE', { level: 9.0, mode: 'idle', speed: 40 }, tags: { unit: 'b' })
    end

    it 'gives its fields with type, newest value and time' do
      data = answer(measurement: 'RAW_DEVICE')

      expect(data[:fields]).to eq(
        active: { type: 'boolean', last: false, last_at: (now - 2.hours).iso8601 },
        speed: { type: 'integer', last: 40, last_at: (now - 1.hour).iso8601 },
        mode: { type: 'string', last: 'idle', last_at: (now - 1.hour).iso8601 },
        level: { type: 'float', last: 9.0, last_at: (now - 1.hour).iso8601 },
      )
    end

    it 'says that no sensor reads its fields' do
      expect(answer(measurement: 'RAW_DEVICE')[:note]).to include('No sensor reads these fields')
    end

    it 'gives its tags and series' do
      expect(answer(measurement: 'RAW_DEVICE')).to include(series_count: 2, tags: { unit: %w[a b] })
    end

    it 'counts the values of a tag with too many of them, and lists only the first' do
      add_influx_points(Array.new(21) { { name: 'RAW_SWARM', tags: { id: format('id%02d', it) }, fields: { level: 1.0 }, time: (now - 1.hour).to_i } })

      tags = answer(measurement: 'RAW_SWARM')[:tags]

      expect(tags[:id]).to include(value_count: 21)
      expect(tags[:id][:values]).to eq(Array.new(20) { format('id%02d', it) })
    end

    it 'says so where nothing was written' do
      data = answer(measurement: 'RAW_NOTHING')

      expect(data[:fields]).to eq({})
      expect(data[:note]).to include('lookback_days')
    end
  end

  it 'names the sensor that reads a field' do
    write(measurement_inverter_power_1, { field_inverter_power_1 => 100.0 })

    data = answer(measurement: measurement_inverter_power_1)

    expect(data.dig(:fields, field_inverter_power_1.to_sym, :sensor)).to eq('inverter_power_1')
    expect(data).not_to include(:note)
  end

  describe 'personal data' do
    before do
      Sensor::Config.setup(ENV.to_h.merge('INFLUX_SENSOR_CAR_LATITUDE_1' => 'RAW_CAR:latitude'))
      write('RAW_CAR', { latitude: 1.40706, odometer: 100.0 })
    end

    after { Sensor::Config.setup(ENV) }

    it 'leaves out the field of an admin-only sensor' do
      expect(answer(measurement: 'RAW_CAR')[:fields].keys).to eq([:odometer])
    end

    it 'does not match the field of an admin-only sensor' do
      data = answer(query: 'latitude')

      expect(data).not_to include(:matching_fields, :fields)
      expect(data[:note]).to include('No measurement or field name contains "latitude"')
    end
  end

  it 'rejects a lookback out of range' do
    error, text = call(lookback_days: 400)

    expect(error).to be(true)
    expect(text).to include('between 1 and 366')
  end

  it 'reports a failing InfluxDB' do
    allow(Influx.query_api).to receive(:query).and_raise(Net::ReadTimeout)

    error, text = call

    expect(error).to be(true)
    expect(text).to include('did not answer')
  end

  it 'finds a measurement whose name has an umlaut' do
    write('RAW_WÄRME', { level: 1.0 })

    expect(answer(query: 'wärme')).to include(measurement: 'RAW_WÄRME')
  end

  it 'is offered only when the admin allows raw data' do
    Setting.mcp_raw_data = false
    expect(described_class.available?).to be(false)

    Setting.mcp_raw_data = true
    expect(described_class.available?).to be(true)
  end
end
