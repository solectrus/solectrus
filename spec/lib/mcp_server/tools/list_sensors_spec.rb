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

    it 'includes a human-readable display name and description' do
      house = data[:sensors].find { _1[:name] == 'house_power' }
      expect(house[:display_name]).to eq('House consumption')
      expect(house[:description]).to eq('Total household electricity consumption.')
    end

    it 'never leaks a raw machine name as the display name' do
      leaks = data[:sensors].select { _1[:display_name] == _1[:name] }
      expect(leaks).to be_empty
    end

    it 'provides a description for every sensor' do
      missing = data[:sensors].reject { _1[:description].present? }
      expect(missing).to be_empty
    end

    it 'derives display name and description for split sensors' do
      grid = data[:sensors].find { _1[:name] == 'house_costs_grid' }
      expect(grid[:display_name]).to eq('House costs (Grid)')
      expect(grid[:description]).to start_with('Portion of "House costs"')
    end

    it 'explains the naming conventions' do
      expect(data[:conventions][:suffixes]).to include(:_grid, :_pv, :_total)
      expect(data[:conventions][:units]).to be_present
    end
  end
end
