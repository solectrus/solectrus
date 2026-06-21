describe McpServer::Tools::ListSensors do
  describe '.call' do
    subject(:data) do
      response = described_class.call(server_context: nil)
      JSON.parse(response.content.first[:text], symbolize_names: true)
    end

    it 'lists configured sensors with their metadata' do
      names = data[:sensors].pluck(:name)
      expect(names).to include('house_power', 'battery_soc')

      soc = data[:sensors].find { _1[:name] == 'battery_soc' }
      expect(soc).to include(unit: 'percent', calculated: false)
      expect(soc[:aggregations]).to be_present
    end
  end
end
