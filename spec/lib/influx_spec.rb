describe Influx do
  describe '.client' do
    it 'returns an InfluxDB2 client' do
      expect(described_class.client).to be_a(InfluxDB2::Client)
    end
  end

  describe '.query_api' do
    subject(:query_api) { described_class.query_api }

    after { query_api.reset! }

    let(:flux) do
      "from(bucket: \"#{Rails.configuration.x.influx.bucket}\") " \
        '|> range(start: -1h) |> limit(n: 1)'
    end

    it 'returns Flux tables' do
      expect(query_api.query(query: flux)).to all(be_a(InfluxDB2::FluxTable))
    end

    it 'keeps the pooled connection usable across queries' do
      3.times { expect(query_api.query(query: flux)).to be_an(Array) }
    end

    it 'raises a QueryError for an invalid query' do
      expect { query_api.query(query: 'this is not flux') }.to raise_error(
        Influx::QueryError,
      )
    end
  end
end
