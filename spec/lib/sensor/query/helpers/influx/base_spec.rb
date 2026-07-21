describe Sensor::Query::Helpers::Influx::Base do
  let(:sensor_names) { %i[inverter_power house_power] }
  let(:timeframe) { Timeframe.now }

  describe '#initialize' do
    it 'inherits from Base class' do
      expect(described_class.superclass).to eq(Sensor::Query::Base)
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
      allow(Influx.query_api).to receive(:query).and_wrap_original do |original, **kwargs|
        sleep delay
        original.call(**kwargs)
      end

      call

      expect(events.map(&:duration)).to all(be >= delay * 1000)
    end
  end
end
