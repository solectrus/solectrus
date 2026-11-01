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
  end
end
