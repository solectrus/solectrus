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

    it 'derives subsystem capabilities from the sensor configuration' do
      response = described_class.call(server_context: nil)
      data = JSON.parse(response.content.first[:text], symbolize_names: true)

      expect(data[:has_battery]).to eq(
        Sensor::Config.exists?(:battery_soc) || Sensor::Config.exists?(:battery_power),
      )
      expect(data[:has_heatpump]).to eq(Sensor::Config.exists?(:heatpump_power))
      expect(data).to include(:has_wallbox, :has_forecast)
    end

    it 'omits the peak power when it is unknown' do
      allow(UpdateCheck).to receive(:kwp).and_return(nil)
      response = described_class.call(server_context: nil)
      data = JSON.parse(response.content.first[:text], symbolize_names: true)

      expect(data).not_to have_key(:installed_peak_power_kwp)
    end

    it 'includes the peak power when known' do
      allow(UpdateCheck).to receive(:kwp).and_return(9.24)
      response = described_class.call(server_context: nil)
      data = JSON.parse(response.content.first[:text], symbolize_names: true)

      expect(data[:installed_peak_power_kwp]).to eq(9.24)
    end
  end
end
