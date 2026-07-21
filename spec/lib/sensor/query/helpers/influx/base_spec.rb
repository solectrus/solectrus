describe Sensor::Query::Helpers::Influx::Base do
  let(:sensor_names) { %i[inverter_power house_power] }
  let(:timeframe) { Timeframe.now }

  describe '#initialize' do
    it 'inherits from Base class' do
      expect(described_class.superclass).to eq(Sensor::Query::Base)
    end
  end

  # A cached result outlives a deploy - a past timeframe is even cached
  # indefinitely - so an entry written by an older format must never be handed
  # to the current parser. That happened once: Influx::CsvParser replaced
  # FluxTable objects with row hashes, and charts of past days kept blowing up
  # on `undefined method '[]' for an instance of InfluxDB2::FluxTable` until
  # Redis was flushed.
  describe 'cache versioning' do
    # Not a memoized subject: the example has to run the very same query twice,
    # once to learn what it looks like and once against the stale cache.
    def run_query
      Sensor::Query::Series.new(%i[inverter_power], Timeframe.new(date.iso8601)).call
    end

    let(:date) { Date.yesterday }

    before do
      # The test environment uses :null_store, which would swallow the stale
      # entry this example is about
      allow(Rails).to receive(:cache).and_return(
        ActiveSupport::Cache::MemoryStore.new,
      )

      add_influx_point(
        name: Sensor::Config.measurement(:inverter_power),
        fields: {
          Sensor::Config.field(:inverter_power) => 1000.0,
        },
        time: date.noon,
      )
    end

    it 'ignores an entry stored under the previous, unversioned key' do
      queries = []
      allow(Influx).to receive(:query).and_wrap_original do |original, flux|
        queries << flux
        original.call(flux)
      end

      run_query # learn which queries this chart issues

      # Reproduce the state right after a deploy: the cache holds only what the
      # previous format wrote, under the key that format used
      store = ActiveSupport::Cache::MemoryStore.new
      allow(Rails).to receive(:cache).and_return(store)
      queries.each do |flux|
        store.write(
          "sensor_influx:#{Digest::SHA256.hexdigest(flux)}",
          :written_by_an_older_deploy,
        )
      end

      expect { run_query }.not_to raise_error
    end
  end

  # The event has to be emitted *around* the backend call. Emitting it
  # afterwards (and passing the measured time as payload) leaves everything
  # reading `event.duration` at zero, which silently hides slow queries.
  describe 'instrumentation' do
    subject(:call) { Sensor::Query::Latest.new([:inverter_power]).call }

    let(:events) do
      collected = []
      ActiveSupport::Notifications.subscribe('query.sensor_influx') do |*args|
        collected << ActiveSupport::Notifications::Event.new(*args)
      end
      collected
    end

    before do
      events # subscribe before the query runs
      add_influx_point(
        name: Sensor::Config.measurement(:inverter_power),
        fields: {
          Sensor::Config.field(:inverter_power) => 1000.0,
        },
        time: 1.minute.ago,
      )
    end

    it 'reports the executed query and its sensors' do
      call

      expect(events.first.payload).to include(
        query: be_present,
        sensors: [:inverter_power],
      )
    end

    # A duration merely being positive would not catch the regression:
    # emitting the event after the fact still takes microseconds. Only a
    # backend call that visibly takes time can tell the two apart.
    it 'measures the backend call' do
      delay = 0.02
      allow(Influx).to receive(:query).and_wrap_original do |original, flux|
        sleep delay
        original.call(flux)
      end

      call

      expect(events.map(&:duration)).to all(be >= delay * 1000)
    end
  end
end
