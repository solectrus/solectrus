describe McpServer::Tools::SensorDetails do
  def call(**args)
    described_class.call(server_context: nil, **args)
  end

  def details(*sensors)
    JSON.parse(call(sensors:).content.first[:text], symbolize_names: true)[:sensors]
  end

  describe '.call' do
    it 'returns the full metadata of a sensor' do
      expect(details('battery_soc').first).to eq(
        name: 'battery_soc',
        display_name: 'Home battery SOC',
        description: Sensor::Registry[:battery_soc].description,
        unit: 'percent',
        category: 'battery',
        calculated: false,
        aggregations: %w[avg min max],
        # No "r": battery_soc is outside the curated ranking set. get_ranking
        # can still rank it - the letter is advisory for t and r.
        tools: 'cts',
      )
    end

    it 'returns one entry per requested sensor, in order' do
      expect(details('house_power', 'battery_soc').pluck(:name)).to eq(
        %w[house_power battery_soc],
      )
    end

    it 'never leaks a raw machine name as the display name' do
      names = Sensor::Config.sensors.map(&:name).take(20)
      leaks = details(*names).select { _1[:display_name] == _1[:name] }

      expect(leaks).to be_empty
    end

    # list_sensors omits the description of a split sensor because the suffix
    # convention already carries it. This is where the spelled-out sentence is
    # available for the client that actually wants it.
    it 'returns the description of a split sensor that list_sensors omits' do
      expect(details('house_costs_grid').first[:description]).to start_with(
        'Portion of "House costs"',
      )
    end

    # specific_yield is a power normalized by installed capacity (W/kWp), not
    # plain watts - MCP reports the honest physical unit.
    it 'reports specific_yield with a per-kWp unit' do
      expect(details('specific_yield').first[:unit]).to eq('watt_per_kwp')
    end

    # Forecast sensors are rejected by get_totals, so advertising a stored
    # aggregation would promise one the tools later reject.
    it 'advertises no aggregations for forecast sensors' do
      expect(details('inverter_power_forecast').first[:aggregations]).to eq([])
    end

    it 'marks a derived sensor as calculated' do
      expect(details('autarky').first[:calculated]).to be(true)
    end

    describe 'with invalid input' do
      it 'reports an unknown sensor' do
        response = call(sensors: ['nonexistent'])

        expect(response.error?).to be(true)
        expect(response.content.first[:text]).to include('Unknown or unconfigured')
      end

      it 'points a typo at list_sensors' do
        expect(call(sensors: ['hause_power']).content.first[:text]).to include(
          'hause_power',
          'list_sensors',
        )
      end

      it 'requires at least one sensor' do
        response = call(sensors: [])

        expect(response.error?).to be(true)
        expect(response.content.first[:text]).to include('at least one sensor')
      end

      # Asking for every sensor rebuilds exactly the payload list_sensors was
      # slimmed down to avoid.
      it 'rejects more than the allowed number of sensors' do
        response = call(sensors: Sensor::Config.sensors.map { _1.name.to_s }.take(21))

        expect(response.error?).to be(true)
        expect(response.content.first[:text]).to include('Too many sensors')
      end
    end
  end
end
