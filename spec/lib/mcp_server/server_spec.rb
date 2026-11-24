describe McpServer::Server do
  describe '.instructions' do
    it 'calls the data read-only while the admin does not allow writing' do
      expect(described_class.instructions).to start_with('Read-only data')
      expect(described_class.instructions).not_to include('set_price')
    end

    it 'names the tools that write once the admin allows them' do
      Setting.mcp_write = true

      expect(described_class.instructions).to start_with('Data of a SOLECTRUS photovoltaic monitoring system, to read and to record.')
      expect(described_class.instructions).to include('set_price', 'Nothing is ever deleted')
    end
  end
end
