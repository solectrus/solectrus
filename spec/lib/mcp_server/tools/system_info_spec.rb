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

    describe 'data freshness' do
      it 'reports when the installation last received data' do
        seen = 5.seconds.ago
        add_influx_point(
          name: Sensor::Config.measurement(:house_power),
          fields: {
            Sensor::Config.field(:house_power) => 500.0,
          },
          time: seen,
        )

        response = described_class.call(server_context: nil)
        data = JSON.parse(response.content.first[:text], symbolize_names: true)[:data]

        expect(Time.iso8601(data[:last_seen_at])).to be_within(1.second).of(seen)
        expect(data[:age_seconds]).to be_between(0, 60)
      end

      # Sensor::Query::Latest looks back exactly one day, so an installation
      # that stopped delivering longer ago than that has nothing in the live
      # window. Reported as a null, that says "never received any data" about
      # the very outage this field exists to surface - and the longer the
      # outage lasts, the more confident the wrong answer becomes.
      it 'dates an outage older than the live window instead of nulling it' do
        seen = 3.days.ago
        add_influx_point(
          name: Sensor::Config.measurement(:house_power),
          fields: {
            Sensor::Config.field(:house_power) => 500.0,
          },
          time: seen,
        )

        response = described_class.call(server_context: nil)
        data = JSON.parse(response.content.first[:text], symbolize_names: true)[:data]

        expect(Time.iso8601(data[:last_seen_at])).to be_within(1.second).of(seen)
        expect(data[:age_seconds]).to be > 2.days
      end

      it 'reports nulls before the first data point' do
        response = described_class.call(server_context: nil)
        data = JSON.parse(response.content.first[:text], symbolize_names: true)[:data]

        expect(data).to eq(last_seen_at: nil, age_seconds: nil)
      end
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
