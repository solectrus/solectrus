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

    # Forecast sensors are rejected by get_totals, so advertising a stored
    # aggregation (e.g. [:sum] on the watt-unit inverter_power_forecast) would
    # promise an aggregation the tools later reject.
    it 'advertises no aggregations for forecast sensors' do
      forecasts = data[:sensors].select { _1[:category] == 'forecast' }
      expect(forecasts).to be_present
      expect(forecasts).to all(include(aggregations: []))
    end

    it 'documents how to access forecast sensors' do
      expect(data[:conventions][:forecast]).to include('get_forecast')
    end

    it 'advertises the supported tools per sensor' do
      house = data[:sensors].find { _1[:name] == 'house_power' }
      expect(house[:supported_tools]).to eq(
        current: true,
        totals: true,
        series: true,
        ranking: true,
        forecast: false,
      )
      expect(data[:conventions][:supported_tools]).to include('get_current_values')
    end

    # power_balance is a chart-only composite with no live scalar, so it must
    # flag current/series false even though it is listed (BUG-2: clients need a
    # machine-readable signal, not just the prose in get_current_values).
    it 'flags chart-only composites as having no live value' do
      balance = data[:sensors].find { _1[:name] == 'power_balance' }
      expect(balance[:supported_tools]).to include(current: false, series: false)
    end

    it 'flags forecast sensors as forecast-only' do
      forecast = data[:sensors].find { _1[:category] == 'forecast' }
      expect(forecast[:supported_tools]).to include(forecast: true, totals: false, series: true)
    end

    # specific_yield is W/kWp (Wh/kWp summed), not plain watts (BUG-3).
    it 'reports specific_yield with a per-kWp unit' do
      yield_sensor = data[:sensors].find { _1[:name] == 'specific_yield' }
      expect(yield_sensor[:unit]).to eq('watt_per_kwp')
    end
  end
end
