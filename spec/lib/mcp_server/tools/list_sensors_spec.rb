describe McpServer::Tools::ListSensors do
  describe '.call' do
    subject(:data) do
      response = described_class.call(server_context: nil)
      JSON.parse(response.content.first[:text], symbolize_names: true)
    end

    it 'lists the configured sensors by name' do
      expect(data[:sensors].pluck(:name)).to include('house_power', 'battery_soc')
    end

    it 'describes a sensor semantically' do
      house = data[:sensors].find { _1[:name] == 'house_power' }
      expect(house[:description]).to eq('Total household electricity consumption.')
    end

    # A sensor is a mechanical split when its name is another LISTED sensor's
    # name plus _grid/_pv - the same rule the tool applies.
    def split?(name, names)
      %w[_grid _pv].any? do |suffix|
        name.end_with?(suffix) && names.include?(name.delete_suffix(suffix))
      end
    end

    # Every entry that survives the filter is a distinct concept, so every one
    # of them has to carry its own description - that is what the index is for.
    it 'provides a description for every listed sensor' do
      expect(data[:sensors].reject { _1[:description].present? }).to be_empty
    end

    # A split says nothing its name and the suffix convention do not, and on an
    # instance with many consumers the splits are 40 % of this response. So
    # they are dropped from the index and reconstructible from split_bases.
    describe 'split sensors' do
      let(:names) { data[:sensors].pluck(:name) }

      it 'are not listed at all' do
        expect(names).not_to include('house_costs_grid', 'house_power_pv')
      end

      it 'keep their base sensor listed with its description' do
        base = data[:sensors].find { _1[:name] == 'house_costs' }

        expect(base[:description]).to be_present
      end

      # Without this list a client would have to guess which sensors can take a
      # suffix, and would sooner or later try battery_soc_grid.
      it 'name their base sensors in the conventions' do
        expect(data[:conventions][:suffixes][:split_bases]).to include(
          'house_costs',
          'house_power',
        )
      end

      it 'list each base exactly once, even though it has two splits' do
        bases = data[:conventions][:suffixes][:split_bases]

        expect(bases).to eq(bases.uniq)
      end

      # The list is the contract: a sensor outside it must not have a split,
      # and one inside it must not have been listed as a sensor itself.
      it 'agree with what was filtered out' do
        bases = data[:conventions][:suffixes][:split_bases]

        expect(bases).to all(be_in(names))
        expect(names & bases.flat_map { |b| ["#{b}_grid", "#{b}_pv"] }).to be_empty
      end

      it 'are explained in the conventions' do
        expect(data[:conventions][:suffixes][:note]).to include('NOT listed')
      end

      # The note promises a split never reads an instant but does have a curve
      # over a finished window, which is the only thing left telling a client
      # what a split supports. Prose alone would drift the moment a sensor
      # family changes.
      it 'carry no c, whatever their base sensor carries' do
        suffixes = %w[_grid _pv]
        splits =
          data[:conventions][:suffixes][:split_bases].flat_map do |base|
            suffixes.filter_map { Sensor::Registry.find(:"#{base}#{_1}") }
          end

        expect(splits).not_to be_empty
        expect(splits.map { McpServer::SupportedTools.code(_1) }).to all(
          match(/\A[tsr]*\z/),
        )
      end

      # The r is what distinguishes the two halves: the summaries store a
      # _grid half, so get_ranking answers for it, while a _pv half is derived
      # from the base and has no per-period value to order by. Both keep the s:
      # a curve is a sequence of periods, which is exactly what a split has.
      it 'rank the stored _grid half but not the derived _pv half' do
        expect(McpServer::SupportedTools.code(Sensor::Registry[:house_power_grid])).to eq('tsr')
        expect(McpServer::SupportedTools.code(Sensor::Registry[:house_power_pv])).to eq('ts')
      end

      # _total aggregates a family rather than splitting one sensor, and there
      # are only a handful of them.
      it 'do not swallow a _total sensor' do
        total = data[:sensors].find { _1[:name] == 'inverter_power_total' }

        expect(total[:description]).to be_present
      end

      # A name merely ending in _pv/_grid without a base sensor behind it is
      # not a split, and dropping it would make it unreachable - nothing would
      # name it. No sensor is currently shaped that way, so asserting it
      # against the response would pass vacuously; the rule is pinned on the
      # predicate that decides it instead.
      it 'are recognized by the base sensor, not by the suffix' do
        names = Set[:house_power, :house_power_pv, :feed_in_pv]

        expect(McpServer::SplitSensors.split?(:house_power_pv, names)).to be(true)
        expect(McpServer::SplitSensors.split?(:feed_in_pv, names)).to be(false)
      end
    end

    # The index carries only what is needed to PICK a sensor. Unit, category
    # and aggregations are a get_sensor_details call away, and every data tool
    # reports them anyway - spelling them out for a few hundred sensors up
    # front is what made this response cost a quarter of a context window.
    it 'omits the per-sensor datasheet fields' do
      keys = data[:sensors].flat_map(&:keys).uniq

      expect(keys - [:display_name]).to contain_exactly(:name, :description, :tools)
    end

    # The one label a client cannot derive: the operator's own name for a
    # sensor is what the user says out loud, and neither custom_power_01 nor
    # "custom consumer 1" reveals that it is the washing machine. Sensors the
    # operator left alone are named by their description already, so repeating
    # an English label for each of them would just cost bytes.
    describe 'the operator\'s own sensor names' do
      before do
        allow(Setting).to receive(:sensor_names).and_return(
          { house_power: 'Hausverbrauch' },
        )
      end

      def entry(name)
        data[:sensors].find { _1[:name] == name }
      end

      it 'carries the configured name' do
        expect(entry('house_power')[:display_name]).to eq('Hausverbrauch')
      end

      it 'omits the field where nothing was configured' do
        expect(entry('battery_soc')).not_to have_key(:display_name)
      end

      # Said in the tool description rather than in `conventions`, because it
      # decides how the client READS the user's question - which it does before
      # the call, not after it.
      it 'tells a client what the field is for' do
        expect(described_class.description.squish).to include(
          'the word the user will say',
        )
      end
    end

    it 'explains the naming conventions' do
      expect(data[:conventions][:suffixes]).to include(:_grid, :_pv, :_total)
      expect(data[:conventions][:units]).to be_present
    end

    it 'publishes the rounding policy' do
      expect(data[:conventions][:precision][:decimals]).to include(watt: 1, watt_hour: 0)
    end

    # Rounding each value independently means a sum of parts can miss the
    # rounded whole by 1 Wh. Left unsaid, a model reports that as a data
    # inconsistency - the cross-checks it runs are exactly these identities.
    it 'warns that independently rounded values can miss an identity by a digit' do
      expect(data[:conventions][:precision][:note]).to include(
        'rounded on its own',
        'not an inconsistency',
      )
    end

    it 'documents how to access forecast sensors' do
      expect(data[:conventions][:forecast]).to include('get_forecast')
    end

    describe 'the tools code' do
      def code_for(name)
        data[:sensors].find { _1[:name] == name }[:tools]
      end

      it 'lists every tool that works for a sensor' do
        expect(code_for('house_power')).to eq('ctsr')
      end

      it 'explains its letters' do
        expect(data[:conventions][:tools]).to include(
          'get_current_values',
          'get_ranking',
        )
      end

      # power_balance is a chart-only composite with no live scalar, so it must
      # advertise neither c nor s even though it is listed - clients need a
      # machine-readable signal, not just the prose in get_current_values.
      it 'omits c and s for a chart-only composite' do
        expect(code_for('power_balance')).not_to include('c', 's')
      end

      # Money sensors (costs, revenue) are accumulated amounts with no
      # instantaneous value and no meaningful per-bucket curve, so they carry
      # neither c nor s.
      it 'marks money sensors as totals-only' do
        expect(code_for('grid_costs')).to eq('tr')
        expect(data[:sensors].select { _1[:tools].match?(/[cs]/) }.pluck(:name)).not_to include(
          'grid_costs',
        )
      end

      # No t: get_totals covers measured actuals and rejects it. The r stays -
      # the summaries do store what was predicted per day, and get_ranking
      # answers for it, so hiding the letter only hid a call that works.
      it 'marks a forecast sensor as forecast-capable and not summable' do
        expect(code_for('inverter_power_forecast')).to eq('csrf')
      end

      # Every strict letter has to mean what the tool does, or a client cannot
      # act on the matrix at all. get_ranking is the one that used to disagree:
      # "r" marked the curated Top 10 set of the UI, not what the tool accepts.
      it 'agrees with what get_ranking accepts' do
        # The two gates get_ranking applies: the summaries have to back the
        # sensor, and it needs an aggregation to rank by.
        rejected = lambda do |sensor|
          McpServer::Tools::Base.__send__(:enforce_rankable!, [sensor])
          sensor.default_aggregation.nil?
        rescue ArgumentError
          true
        end

        mismatched =
          Sensor::Config.sensors.reject do |sensor|
            McpServer::SupportedTools.supports?(sensor, :ranking) == !rejected.call(sensor)
          end

        expect(mismatched.map(&:name)).to be_empty
      end

      # A boolean or string sensor has a present state but no curve: no
      # aggregation folds it into a time bucket. Advertising the s made
      # clients ask get_series for something the query could not answer.
      it 'marks a non-numeric sensor as live but curve-less' do
        expect(code_for('wallbox_car_connected')).to eq('c')
        expect(code_for('heatpump_status')).to eq('c')
      end
    end
  end
end
