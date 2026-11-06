describe Influx do
  describe '.ping?' do
    it 'answers for a running InfluxDB' do
      expect(described_class.ping?).to be true
    end

    it 'answers while the queries hold every pooled connection' do
      pool = described_class.query_api.__send__(:pool)
      allow(pool).to receive(:with).and_raise(ConnectionPool::TimeoutError)

      aggregate_failures do
        expect(described_class.ping?).to be true
        expect(described_class.version).to be_present
      end
    end
  end

  describe '.version' do
    it 'returns the version that InfluxDB reports' do
      expect(described_class.version).to match(/\Av?\d+\.\d+/)
    end
  end

  describe '.query' do
    after { described_class.query_api.reset! }

    let(:flux) do
      "from(bucket: \"#{Rails.configuration.x.influx.bucket}\") " \
        '|> range(start: -1h) |> limit(n: 1)'
    end

    it 'returns rows as hashes' do
      expect(described_class.query(flux)).to all(be_a(Hash))
    end

    it 'keeps the pooled connection usable across queries' do
      3.times { expect(described_class.query(flux)).to be_an(Array) }
    end

    it 'raises a QueryError for an invalid query' do
      expect { described_class.query('this is not flux') }.to raise_error(
        Influx::QueryError,
      )
    end

    it 'raises a QueryError when every pooled connection is busy' do
      pool = described_class.query_api.__send__(:pool)
      allow(pool).to receive(:with).and_raise(ConnectionPool::TimeoutError, 'Waited 5 sec')

      expect { described_class.query(flux) }.to raise_error(
        Influx::QueryError,
        /connection pool exhausted: Waited 5 sec/,
      )
    end

    describe 'with a dropped connection' do
      # The first `count` requests fail as if the server had closed the
      # kept-alive socket, the later ones reach InfluxDB
      def drop_requests(count)
        attempts = 0
        allow(Net::HTTP).to receive(:new).and_wrap_original do |original, *args|
          original.call(*args).tap do |http|
            allow(http).to receive(:request).and_wrap_original do |request, *request_args, &block|
              attempts += 1
              raise Errno::ECONNRESET if attempts <= count

              request.call(*request_args, &block)
            end
          end
        end
        described_class.query_api.reset!
      end

      it 'reconnects and retries the query' do
        drop_requests(2)

        expect(described_class.query(flux)).to be_an(Array)
      end

      it 'gives up after two retries' do
        drop_requests(3)

        expect { described_class.query(flux) }.to raise_error(
          Influx::QueryError,
          /failed after 2 retries/,
        )
      end
    end

    describe 'with a timeout' do
      def read_timeouts
        timeouts = []
        described_class.query_api.__send__(:pool).with { timeouts << it.read_timeout }
        timeouts
      end

      it 'gives the one query the time that is left as its read timeout' do
        used = nil
        allow(Net::HTTP).to receive(:new).and_wrap_original do |original, *args|
          original.call(*args).tap do |http|
            allow(http).to receive(:request).and_wrap_original do |request, *request_args, &block|
              used = http.read_timeout
              request.call(*request_args, &block)
            end
          end
        end
        described_class.query_api.reset!

        described_class.query_api.query(flux, timeout: 7)

        expect(used).to be_within(1).of(7)
      end

      it 'raises Net::ReadTimeout when no time is left' do
        expect { described_class.query_api.query(flux, timeout: 0) }.to raise_error(Net::ReadTimeout)
      end

      it 'restores the default afterwards' do
        described_class.query_api.query(flux, timeout: 7)

        expect(read_timeouts).to eq([30])
      end

      it 'raises Net::ReadTimeout when InfluxDB takes longer' do
        allow_any_instance_of(Net::HTTP).to receive(:request).and_raise(Net::ReadTimeout) # rubocop:disable RSpec/AnyInstance

        expect { described_class.query_api.query(flux, timeout: 1) }.to raise_error(Net::ReadTimeout)
        expect(read_timeouts).to eq([30])
      end
    end

    describe 'with max_bytes' do
      let(:flux) do
        <<~FLUX
          import "array"
          array.from(rows: [{_value: "#{'x' * 2000}"}, {_value: "#{'y' * 2000}"}])
        FLUX
      end

      it 'stops an answer that grows past it' do
        expect { described_class.query_api.query(flux, max_bytes: 1000) }.to raise_error(Influx::ResponseTooLarge)
      end

      it 'keeps the connection usable for the next query' do
        expect { described_class.query_api.query(flux, max_bytes: 1000) }.to raise_error(Influx::ResponseTooLarge)

        expect(described_class.query_api.query(flux, max_bytes: 10_000).size).to eq(2)
      end
    end

    it 'reads a string as UTF-8, also with a line break' do
      rows = described_class.query(%(import "array"\narray.from(rows: [{_value: "Wärme\\n°C"}])))

      expect(rows.first['_value']).to eq("Wärme\n°C")
    end
  end
end
