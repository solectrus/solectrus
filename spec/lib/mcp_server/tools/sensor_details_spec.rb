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
        default_aggregation: 'avg',
        # "r" because get_ranking answers for it: the summaries store it. The
        # letter used to mark the curated Top 10 set of the UI instead, so a
        # working call read as unavailable.
        tools: 'ctsr',
      )
    end

    # get_totals applies one of the listed aggregations without being told
    # which. Naming it is what lets a client commit to a unit before the call
    # rather than reading it back off the answer.
    it 'names the aggregation get_totals will apply' do
      expect(details('house_power').first).to include(
        aggregations: %w[sum max],
        default_aggregation: 'sum',
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

    # `aggregations` answers one question - what to pass get_ranking - and
    # get_ranking does rank a forecast sensor. Reporting [] here to express
    # that get_totals rejects it made the field say two things at once and
    # denied an aggregation the tool then demanded; the missing "t" says it
    # instead.
    it 'advertises the aggregation get_ranking accepts for a forecast sensor' do
      details = details('inverter_power_forecast').first

      expect(details[:aggregations]).to eq(%w[sum])
      expect(details[:tools]).not_to include('t')
    end

    it 'marks a derived sensor as calculated' do
      expect(details('autarky').first[:calculated]).to be(true)
    end

    # Nothing measures a power split: the Power Splitter service derives both
    # halves from the base sensor and the grid flow. The _grid half carries no
    # `calculate` block, only a stored field, so it used to report itself as a
    # measurement - which invited a client to trust it over the base sensor.
    it 'marks both halves of a power split as calculated' do
      expect(details('house_power_grid', 'house_power_pv').pluck(:calculated)).to eq(
        [true, true],
      )
    end

    # Money is an energy multiplied by a tariff - nothing meters a cost. Most
    # economic sensors state that arithmetic as SQL over the summaries rather
    # than as a Ruby `calculate` block, and the flag used to follow the block
    # alone, so the most obviously derived family in the system read as
    # measured.
    it 'marks an economic sensor as calculated, whether it computes in Ruby or SQL' do
      sql_derived = %w[grid_costs grid_revenue opportunity_costs house_costs_grid]
      ruby_derived = %w[total_costs savings]
      entries = details(*sql_derived, *ruby_derived)

      expect(entries.pluck(:name)).to eq(sql_derived + ruby_derived)
      expect(entries.pluck(:calculated)).to all(be(true))
    end

    # The flag has to keep separating the two, or it says nothing.
    it 'still marks a metered sensor as measured' do
      expect(details('grid_import_power', 'battery_soc').pluck(:calculated)).to all(
        be(false),
      )
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
