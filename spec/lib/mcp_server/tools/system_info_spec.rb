describe McpServer::Tools::SystemInfo do
  describe '.call' do
    it 'returns installation metadata' do
      response = described_class.call(server_context: nil)

      expect(response.error?).to be(false)
      data = JSON.parse(response.content.first[:text], symbolize_names: true)

      expect(data[:currency]).to eq(Rails.configuration.x.currency)
      expect(data[:timezone]).to eq(Time.zone.name)
      expect(data[:installation_date]).to eq(
        Rails.configuration.x.installation_date.iso8601,
      )
    end
  end
end
