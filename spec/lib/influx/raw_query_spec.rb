describe Influx::RawQuery do
  subject(:raw_query) { described_class.new }

  let(:start) { Time.zone.local(2026, 1, 11, 5, 30) }
  let(:stop) { Time.zone.local(2026, 1, 11, 5, 40) }
  # Everything a raw query may call. None of them writes.
  let(:read_functions) do
    %w[from range filter last count keep group distinct drop yield aggregateWindow map difference float limit]
  end

  # Names a client could send to break out of a string literal and run Flux
  # of its own: a write with to(), an interpolation, a comment
  hostile = [
    'x") |> to(bucket: "other") //',
    'x\") |> drop(columns: ["_value"]) //',
    'x${string(v: 1)}',
    'x" or true or "',
  ]

  # The function calls of a program, with every string literal removed: what
  # is left is the code the program runs. `and (` is a grouping, not a call.
  def calls(flux)
    flux.gsub(/"(?:[^"\\]|\\.)*"/, '""').scan(/([A-Za-z_][\w.]*)\s*\(/).flatten.uniq - %w[and or]
  end

  def flux_of
    programs = []
    allow(Influx.query_api).to receive(:query) do |flux, **|
      programs << flux
      []
    end
    yield
    programs
  end

  describe '.literal' do
    it 'escapes the backslash, the quote and an interpolation' do
      expect(described_class.literal('a"b\\c${d}$e')).to eq('"a\\"b\\\\c\\${d}$e"')
    end
  end

  describe 'timeout' do
    it 'holds for all its queries together' do
      clock = 100.0
      allow(Process).to receive(:clock_gettime).and_call_original
      allow(Process).to receive(:clock_gettime).with(Process::CLOCK_MONOTONIC) { clock }
      timeouts = []
      allow(Influx.query_api).to receive(:query) do |_flux, timeout:, **|
        timeouts << timeout
        clock += 5
        []
      end

      raw_query = described_class.new(timeout: 20)
      2.times { raw_query.fields(start:, stop:) }

      expect(timeouts).to eq([20.0, 15.0])
    end
  end

  describe 'the programs it builds' do
    hostile.each do |name|
      it "call only read functions for the name #{name.inspect}" do
        selection =
          described_class::Selection.new(
            measurement: name,
            fields: [name, 'b'],
            tags: { name => name },
            start:,
            stop:,
          )

        programs =
          flux_of do
            raw_query.fields(start:, stop:)
            raw_query.latest_and_counts(selection)
            raw_query.samples(selection)
            raw_query.windows(selection, every: 6.hours, function: :max, types: { name => ['string'], 'b' => ['boolean'] })
            raw_query.changes(selection, types: { name => ['string'], 'b' => ['boolean'] }, limit: 10, max_states: 50)
          end

        expect(programs.size).to eq(6)
        programs.each { expect(calls(it) - read_functions).to be_empty }
      end
    end

    # "last" takes every type as it is, so the storage reads the window once
    it 'reads every type in one stream for "last"' do
      selection = described_class::Selection.new(measurement: 'm', fields: %w[f b s], start:, stop:)
      types = { 'f' => ['float'], 'b' => ['boolean'], 's' => ['string'] }

      programs = flux_of { raw_query.windows(selection, every: 60, function: :last, types:) }

      expect(programs.first.scan('yield(').size).to eq(1)
      expect(programs.first).not_to include('toInt()')
    end

    it 'rejects an aggregation it does not know' do
      selection = described_class::Selection.new(measurement: 'm', fields: ['f'], start:, stop:)

      expect { raw_query.windows(selection, every: 60, function: :sum) }.to raise_error(ArgumentError)
    end
  end

  # The same names against a real InfluxDB: the program parses, finds nothing,
  # and leaves the bucket as it was
  describe 'with InfluxDB' do
    let(:probe) { described_class::Selection.new(measurement: 'RAW_PROBE', fields: ['value'], start:, stop:) }

    before do
      travel_to stop
      add_influx_points([{ name: 'RAW_PROBE', fields: { value: 1.0 }, time: (stop - 1.minute).to_i }])
    end

    hostile.each do |name|
      it "reads nothing and writes nothing for the name #{name.inspect}" do
        selection = described_class::Selection.new(measurement: name, fields: [name], tags: { name => name }, start:, stop:)

        expect(raw_query.samples(selection)).to eq([])
        expect(raw_query.fields(start:, stop:).keys).not_to include(name, 'other')
        expect(raw_query.samples(probe).pluck('_value')).to eq([1.0])
      end
    end

    it 'finds a series whose names need escaping' do
      add_influx_points(
        [{ name: 'RAW "odd" name', tags: { 'k"${y}' => 'v"' }, fields: { 'f${x}' => 2.0 }, time: (stop - 1.minute).to_i }],
      )
      selection =
        described_class::Selection.new(
          measurement: 'RAW "odd" name',
          fields: ['f${x}'],
          tags: { 'k"${y}' => 'v"' },
          start:,
          stop:,
        )

      expect(raw_query.samples(selection).pluck('_value')).to eq([2.0])
    end
  end
end
