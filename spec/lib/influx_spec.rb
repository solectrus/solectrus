describe Influx do
  describe '.client' do
    it 'returns an InfluxDB2 client' do
      expect(described_class.client).to be_a(InfluxDB2::Client)
    end
  end

  describe '.query_api' do
    it 'returns a query API' do
      expect(described_class.query_api).to be_a(InfluxDB2::QueryApi)
    end
  end
end
