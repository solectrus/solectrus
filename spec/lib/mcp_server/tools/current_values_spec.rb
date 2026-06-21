describe McpServer::Tools::CurrentValues do
  describe '.call' do
    # The underlying InfluxDB read is covered by Sensor::Query::Latest specs;
    # here we deterministically test the tool's response shaping by stubbing it.
    it 'returns the latest reading for the requested sensor' do
      data =
        Sensor::Data::Single.new(
          { battery_soc: 85.5 },
          timeframe: Timeframe.now,
          time: Time.current,
        )
      allow(Sensor::Query::Latest).to receive(:new).with([:battery_soc]).and_return(
        instance_double(Sensor::Query::Latest, call: data),
      )

      response = described_class.call(server_context: nil, sensors: ['battery_soc'])

      expect(response.error?).to be(false)
      parsed = JSON.parse(response.content.first[:text], symbolize_names: true)
      value = parsed[:values].find { _1[:name] == 'battery_soc' }
      expect(value[:value]).to eq(85.5)
      expect(value[:unit]).to eq('percent')
    end

    it 'returns exactly the requested sensors, not the dependencies pulled in for calculated ones' do
      requested = %i[inverter_power house_power battery_soc grid_power]

      # Latest resolves calculated sensors to their raw dependencies
      # (grid_power -> grid_import/export, house_power -> heatpump_power, ...)
      # and loads those too; they must not leak into the response.
      data =
        Sensor::Data::Single.new(
          {
            inverter_power: 1000.0,
            house_power: 500.0,
            battery_soc: 85.5,
            grid_power: -200.0,
            heatpump_power: 300.0,
            grid_export_power: 200.0,
            grid_import_power: 0.0,
          },
          timeframe: Timeframe.now,
          time: Time.current,
        )
      allow(Sensor::Query::Latest).to receive(:new).with(requested).and_return(
        instance_double(Sensor::Query::Latest, call: data),
      )

      response =
        described_class.call(server_context: nil, sensors: requested.map(&:to_s))

      expect(response.error?).to be(false)
      parsed = JSON.parse(response.content.first[:text], symbolize_names: true)
      expect(parsed[:values].pluck(:name)).to contain_exactly(
        'inverter_power',
        'house_power',
        'battery_soc',
        'grid_power',
      )
    end

    it 'returns all configured sensors when no filter is given' do
      all_names = Sensor::Config.sensors.map(&:name)
      data =
        Sensor::Data::Single.new(
          all_names.index_with { 0.0 },
          timeframe: Timeframe.now,
          time: Time.current,
        )
      allow(Sensor::Query::Latest).to receive(:new).and_return(
        instance_double(Sensor::Query::Latest, call: data),
      )

      response = described_class.call(server_context: nil)

      expect(response.error?).to be(false)
      parsed = JSON.parse(response.content.first[:text], symbolize_names: true)
      expect(parsed[:values].pluck(:name)).to match_array(all_names.map(&:to_s))
    end

    it 'reports unknown or unconfigured sensors' do
      response = described_class.call(server_context: nil, sensors: ['nonexistent'])

      expect(response.error?).to be(true)
      expect(response.content.first[:text]).to include('Unknown or unconfigured')
    end
  end
end
