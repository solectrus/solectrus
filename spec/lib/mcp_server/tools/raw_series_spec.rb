describe McpServer::Tools::RawSeries do
  # A measurement of its own: InfluxDB pins a field to the type it was first
  # written with, and the types are what these examples are about
  let(:measurement) { 'RAW_DEVICE' }
  let(:now) { Time.zone.local(2026, 1, 11, 6) }
  let(:start) { Time.zone.local(2026, 1, 11, 5, 30) }

  before { travel_to now }

  def write(offset, fields, tags: nil)
    add_influx_points([{ name: measurement, tags:, fields:, time: (start + offset).to_i }])
  end

  def call(**args)
    response = described_class.call(measurement:, start: start.iso8601, stop: (start + 10.minutes).iso8601, **args)
    text = response.content.first[:text]

    response.error? ? [true, text] : [false, JSON.parse(text, symbolize_names: true)]
  end

  def answer(**args)
    error, data = call(**args)
    expect(error).to be(false), "Unexpected error: #{data}"

    data
  end

  def error(**args)
    error, text = call(**args)
    expect(error).to be(true), "Expected an error, got #{text}"

    text
  end

  def field(data, name, series: 0)
    data.dig(:series, series, :fields, name)
  end

  describe 'samples' do
    # One field is written every 10 seconds, the other only when it changes,
    # and never at the same second as the first
    before do
      write(0, { level: 12.300000190734863 })
      write(5, { active: false })
      write(10, { level: 12.5 })
      write(20, { level: 0.0 })
      write(60, { active: true, mode: 'idle', speed: 40 })
    end

    it 'gives every field its own times' do
      data = answer(fields: %w[level active])

      expect(field(data, :level)).to include(type: 'float', t: [0, 10, 20], values: [12.3, 12.5, 0.0])
      expect(field(data, :active)).to eq(type: 'boolean', t: [5, 60], values: [false, true])
      expect(data).to include(aggregation: 'none', point_count: 5, start: start.iso8601)
    end

    it 'states the highest and lowest value of a number with its time' do
      data = answer(fields: %w[level active])

      expect(field(data, :level)).to include(
        max: { at: (start + 10.seconds).iso8601, value: 12.5 },
        min: { at: (start + 20.seconds).iso8601, value: 0.0 },
      )
      expect(field(data, :active)).not_to include(:max, :min)
    end

    it 'keeps the type of strings and integers' do
      data = answer(fields: %w[mode speed])

      expect(field(data, :mode)).to eq(type: 'string', t: [60], values: ['idle'])
      expect(field(data, :speed)).to include(type: 'integer', t: [60], values: [40])
    end

    it 'keeps the requested order of the fields' do
      data = answer(fields: %w[speed level])

      expect(data.dig(:series, 0, :fields).keys).to eq(%i[speed level])
    end

    it 'names a field without a sample instead of failing' do
      data = answer(fields: %w[level no_such_field])

      expect(data[:missing_fields]).to eq(['no_such_field'])
      expect(data[:missing_note]).to include('list_measurements')
      expect(field(data, :level)[:values]).to eq([12.3, 12.5, 0.0])
    end

    it 'answers an empty window with an empty list' do
      data = answer(fields: %w[level], start: (start - 1.hour).iso8601, stop: (start - 30.minutes).iso8601)

      expect(data).to include(series: [], point_count: 0, missing_fields: ['level'])
    end

    it 'reads only the window' do
      data = answer(fields: %w[level], start: (start + 5.seconds).iso8601, stop: (start + 20.seconds).iso8601)

      # The stop is exclusive, the times count from the start asked for
      expect(field(data, :level)).to include(t: [5], values: [12.5])
    end

    it 'rejects more samples than the budget instead of cutting them' do
      stub_const("#{described_class}::MAX_POINTS", 2)

      expect(error(fields: %w[level])).to include('3 samples', 'more than 2')
    end
  end

  describe 'aggregation' do
    before do
      write(0, { level: 10.0, active: false, mode: 'idle' })
      write(30, { level: 20.0, active: true, mode: 'busy' })
      write(70, { level: 5.0, active: false, mode: 'idle' })
    end

    it 'gives one value per window, at its start' do
      data = answer(fields: %w[level], aggregation: 'mean', resolution: '1m')

      expect(data).to include(aggregation: 'mean', resolution: '1m', point_count: 2)
      expect(field(data, :level)).to include(type: 'float', t: [0, 60], values: [15.0, 5.0])
    end

    it 'counts booleans as 0/1 and says so' do
      data = answer(fields: %w[active], aggregation: 'max', resolution: '1m')

      expect(field(data, :active)).to include(type: 'boolean', t: [0, 60], values: [1, 0])
      expect(data[:boolean_note]).to include('true at least once')
    end

    # The first window holds false and true, the second false alone
    it 'gives the share of true samples and whether all were true' do
      mean = answer(fields: %w[active], aggregation: 'mean', resolution: '1m')
      min = answer(fields: %w[active], aggregation: 'min', resolution: '1m')

      expect(field(mean, :active)).to include(t: [0, 60], values: [0.5, 0.0])
      expect(field(min, :active)).to include(t: [0, 60], values: [0, 0])
    end

    it 'aggregates a flag that was always true as 1 for min' do
      write(80, { active: true })
      write(90, { active: true })

      data = answer(fields: %w[active], aggregation: 'min', start: (start + 80.seconds).iso8601, stop: (start + 2.minutes).iso8601, resolution: '1m')

      expect(field(data, :active)).to include(values: [1])
    end

    it 'takes the last value of a string and names that aggregation' do
      data = answer(fields: %w[mode level], aggregation: 'max', resolution: '1m')

      expect(field(data, :mode)).to eq(
        type: 'string',
        aggregation: 'last',
        t: [0, 60],
        values: %w[busy idle],
      )
      expect(field(data, :level)[:values]).to eq([20.0, 5.0])
    end

    # The window runs 10 minutes, the samples stop after the second one
    it 'counts the samples of every type, and gives a window without one as 0' do
      data = answer(fields: %w[mode active], aggregation: 'count', resolution: '1m')

      %i[mode active].each do |name|
        expect(field(data, name)).to include(
          type: 'integer',
          t: (0..540).step(60).to_a,
          values: [2, 1, 0, 0, 0, 0, 0, 0, 0, 0],
          min: { at: (start + 2.minutes).iso8601, value: 0 },
        )
      end
      expect(data).not_to include(:boolean_note)
    end

    it 'chooses the finest resolution that fits the budget' do
      stub_const("#{described_class}::MAX_POINTS", 30)

      # 10 minutes in 1m windows are 11 per field, 22 for both
      expect(answer(fields: %w[level active], aggregation: 'last')).to include(resolution: '1m')
    end

    it 'rejects a resolution over the budget and names the one that fits' do
      stub_const("#{described_class}::MAX_POINTS", 30)

      expect(error(fields: %w[level], aggregation: 'mean', resolution: '10s')).to include(
        'up to 61 points',
        'Use resolution "30s"',
      )
    end

    it 'asks for fewer fields where no resolution fits the budget' do
      stub_const("#{described_class}::MAX_POINTS", 3)

      # Even at 6h the 10 minutes are 2 windows per field, 4 for both
      expect(error(fields: %w[level active], aggregation: 'max')).to include(
        'At resolution "6h" this request returns up to 4 points',
        'Ask for fewer fields',
      )
    end

    # "P30D" ends yesterday. 30 days in 15m windows are 2881 points.
    it 'aggregates a long window' do
      write(-1.day, { level: 7.0 })

      data = answer(fields: %w[level], aggregation: 'max', start: nil, stop: nil, timeframe: 'P30D')

      expect(data).to include(start: (now.to_date - 30).beginning_of_day.iso8601, resolution: '15m')
      expect(field(data, :level)[:values]).to eq([7.0])
    end
  end

  # Every ten seconds the same as before, except at 20 and 40
  describe 'changes' do
    before do
      write(0, { level: 1.0, active: false, mode: 'idle' })
      write(10, { level: 1.0, active: false, mode: 'idle' })
      write(20, { level: 2.0, active: true, mode: 'busy' })
      write(30, { level: 2.0, active: true, mode: 'busy' })
      write(40, { level: 1.0, active: false, mode: 'idle' })
    end

    it 'gives the first sample and every change, of each type' do
      data = answer(fields: %w[active mode level], aggregation: 'changes')

      expect(field(data, :active)).to eq(type: 'boolean', t: [0, 20, 40], values: [false, true, false])
      expect(field(data, :mode)).to eq(type: 'string', t: [0, 20, 40], values: %w[idle busy idle])
      expect(field(data, :level)).to include(type: 'float', t: [0, 20, 40], values: [1.0, 2.0, 1.0])
      expect(data).to include(aggregation: 'changes', point_count: 9, changes_note: include('gap'))
      expect(data).not_to include(:resolution, :boolean_note)
    end

    it 'rejects more changes than the budget instead of cutting them' do
      stub_const("#{described_class}::MAX_POINTS", 2)

      expect(error(fields: %w[active], aggregation: 'changes')).to include('more than 2 times')
    end

    it 'rejects a string field with too many values' do
      stub_const("#{described_class}::MAX_STATES", 1)

      expect(error(fields: %w[mode], aggregation: 'changes')).to include('mode', 'more than 1 different values')
    end

    it 'rejects a resolution' do
      expect(error(fields: %w[active], aggregation: 'changes', resolution: '1m')).to include('takes no `resolution`')
    end

    it 'rejects more samples than it reads, before it reads them' do
      stub_const("#{described_class}::MAX_CHANGES_SAMPLES", 9)
      allow(Influx.query_api).to receive(:query).and_call_original

      expect(error(fields: %w[level active], aggregation: 'changes')).to include('holds 10 samples', 'Shorten it to about 9 minutes', '"count" per window')
      expect(Influx.query_api).not_to have_received(:query).with(/difference/, any_args)
    end

    it 'rejects a window over 31 days' do
      expect(error(fields: %w[active], aggregation: 'changes', start: '2025-12-01T00:00:00Z')).to include('at most 31 days')
    end
  end

  describe 'series and tags' do
    before do
      write(0, { level: 1.0 }, tags: { unit: 'a' })
      write(1, { level: 2.0 }, tags: { unit: 'b' })
    end

    it 'answers each series with its tags' do
      data = answer(fields: %w[level])

      expect(data[:series].pluck(:tags)).to eq([{ unit: 'a' }, { unit: 'b' }])
      expect(data[:series].map { it.dig(:fields, :level).slice(:t, :values) }).to eq(
        [{ t: [0], values: [1.0] }, { t: [1], values: [2.0] }],
      )
    end

    it 'narrows them by `tags`' do
      data = answer(fields: %w[level], tags: { 'unit' => 'b' })

      expect(data[:tags]).to eq(unit: 'b')
      expect(data[:series].pluck(:tags)).to eq([{ unit: 'b' }])
    end

    it 'rejects more series than the cap and names the tags' do
      stub_const("#{described_class}::MAX_SERIES", 1)

      expect(error(fields: %w[level])).to include('2 series', 'tag names: unit')
    end
  end

  describe 'the window' do
    before { write(0, { level: 1.0 }) }

    it 'takes a relative timeframe' do
      data = answer(fields: %w[level], start: nil, stop: nil, timeframe: 'P24H')

      expect(data).to include(stop: now.iso8601, start: (now - 24.hours).iso8601)
      expect(field(data, :level)[:values]).to eq([1.0])
    end

    it 'ends now at the latest' do
      expect(answer(fields: %w[level], stop: (now + 1.day).iso8601)[:stop]).to eq(now.iso8601)
    end

    it 'defaults the stop to now' do
      expect(answer(fields: %w[level], stop: nil)[:stop]).to eq(now.iso8601)
    end

    {
      'a raw window over 7 days' => [{ start: '2026-01-01T00:00:00Z' }, 'at most 7 days'],
      'a window over 366 days' => [{ start: '2024-01-01T00:00:00Z', aggregation: 'max' }, 'at most 366 days'],
      'a start in the future' => [{ start: '2026-01-12T00:00:00Z', stop: nil }, 'in the future'],
      'a stop before the start' => [{ stop: '2026-01-11T05:00:00+01:00' }, 'after `start`'],
      'an invalid timestamp' => [{ start: 'yesterday' }, 'not an ISO 8601 timestamp'],
      'a timeframe next to start' => [{ timeframe: 'P24H' }, 'not both'],
      'an invalid timeframe' => [{ start: nil, stop: nil, timeframe: 'last week' }, 'not a valid timeframe'],
      'no window at all' => [{ start: nil, stop: nil }, 'Give `start`'],
    }.each do |label, (args, message)|
      it "rejects #{label}" do
        expect(error(fields: %w[level], **args)).to include(message)
      end
    end
  end

  describe 'invalid arguments' do
    {
      'more than 10 fields' => [{ fields: Array.new(11) { "f#{it}" } }, 'Too many fields'],
      'no field' => [{ fields: [] }, 'at least one field'],
      'an empty measurement' => [{ measurement: '', fields: %w[a] }, 'Invalid measurement'],
      'a control character' => [{ fields: ["a\nb"] }, 'Invalid field'],
      'an unknown aggregation' => [{ fields: %w[a], aggregation: 'sum' }, 'Invalid aggregation'],
      'a resolution without aggregation' => [{ fields: %w[a], resolution: '1m' }, 'needs an aggregation'],
      'an unknown resolution' => [{ fields: %w[a], aggregation: 'max', resolution: '2m' }, 'Invalid resolution'],
      'a column as tag' => [{ fields: %w[a], tags: { '_field' => 'x' } }, 'no tags'],
      'a tag that is no string' => [{ fields: %w[a], tags: { 'unit' => 1 } }, 'give a string'],
      'too many tags' => [{ fields: %w[a], tags: (1..6).to_h { ["t#{it}", 'x'] } }, 'Too many tags'],
    }.each do |label, (args, message)|
      it "rejects #{label}" do
        expect(error(**args)).to include(message)
      end
    end
  end

  it 'sends a sensor name without data to the sensor tools' do
    text = error(measurement: 'inverter_power', fields: %w[value])

    expect(text).to include('is a sensor', 'get_series')
  end

  describe 'personal data' do
    before do
      Sensor::Config.setup(ENV.to_h.merge('INFLUX_SENSOR_CAR_LATITUDE_1' => "#{measurement}:latitude"))
      write(0, { latitude: 1.40706 })
    end

    after { Sensor::Config.setup(ENV) }

    it 'withholds the field of an admin-only sensor' do
      expect(error(fields: %w[level latitude])).to include('latitude', 'only the admin sees')
    end
  end

  describe 'a failing InfluxDB' do
    it 'reports a timeout with what to change' do
      allow(Influx.query_api).to receive(:query).and_raise(Net::ReadTimeout)

      expect(error(fields: %w[level])).to include('5 seconds', 'shorter window')
    end

    it 'reports an error without its details' do
      allow(Influx.query_api).to receive(:query).and_raise(Influx::QueryError, 'Flux: from(bucket: "my-bucket") token')

      text = error(fields: %w[level])

      expect(text).to eq('InfluxDB could not answer this query. Try again later.')
    end

    it 'cuts the query off after the timeout, and a large answer while it arrives' do
      allow(Influx.query_api).to receive(:query).and_return([])

      answer(fields: %w[level])

      expect(Influx.query_api).to have_received(:query).with(
        anything,
        timeout: a_value_within(1).of(McpServer::RawData::TIMEOUT),
        max_bytes: McpServer::RawData::MAX_BYTES,
      )
    end
  end

  it 'reads a string with umlauts and line breaks' do
    write(0, { mode: "Wärme\nläuft" })

    data = answer(fields: %w[mode])

    expect(field(data, :mode)[:values]).to eq(["Wärme\nläuft"])
  end

  it 'rejects a start before 1970' do
    expect(error(fields: %w[level], start: '1969-12-31T23:00:00Z', stop: '1970-01-01T01:00:00Z')).to include('1970')
  end

  it 'is offered only when the admin allows raw data' do
    Setting.mcp_raw_data = false
    expect(described_class.available?).to be(false)

    Setting.mcp_raw_data = true
    expect(described_class.available?).to be(true)
  end

  it 'is announced as read-only' do
    expect(described_class.annotations.to_h).to include(readOnlyHint: true, destructiveHint: false)
  end
end
