describe McpServer::Tools::CurrentValues do
  describe '.call' do
    # The underlying InfluxDB read is covered by Sensor::Query::Latest specs;
    # here we deterministically test the tool's response shaping by stubbing it.
    it 'returns the latest reading for the requested sensor' do
      data =
        Sensor::Data::Single.new(
          { battery_soc: 85.5 },
          timeframe: Timeframe.now,
          times: { battery_soc: Time.current },
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
          times: { inverter_power: Time.current },
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

    it 'returns all configured live sensors when no filter is given' do
      all_names = Sensor::Config.sensors.map(&:name)
      data =
        Sensor::Data::Single.new(
          all_names.index_with { 0.0 },
          timeframe: Timeframe.now,
          times: all_names.index_with { Time.current },
        )
      allow(Sensor::Query::Latest).to receive(:new).and_return(
        instance_double(Sensor::Query::Latest, call: data),
      )

      response = described_class.call(server_context: nil)

      expect(response.error?).to be(false)
      parsed = JSON.parse(response.content.first[:text], symbolize_names: true)
      # All sensors except chart-only composites (no live scalar) are returned.
      expect(parsed[:values].pluck(:name)).not_to include('power_balance')
      expect(parsed[:values].pluck(:name)).to include('inverter_power', 'house_power')
    end

    describe 'display names' do
      let(:data) do
        Sensor::Data::Single.new(
          { battery_soc: 85.5 },
          timeframe: Timeframe.now,
          times: { battery_soc: Time.current },
        )
      end

      before do
        allow(Sensor::Query::Latest).to receive(:new).and_return(
          instance_double(Sensor::Query::Latest, call: data),
        )
      end

      def values(**args)
        response = described_class.call(server_context: nil, **args)
        JSON.parse(response.content.first[:text], symbolize_names: true)[:values]
      end

      it 'names explicitly requested sensors' do
        expect(values(sensors: ['battery_soc']).first).to include(:display_name)
      end

      # ~70 sensors, each carrying a name that list_sensors already has.
      it 'leaves the names out of the full default set' do
        expect(values.first).not_to have_key(:display_name)
      end
    end

    it 'omits chart-only composites from the default set and rejects them when asked' do
      # power_balance is a calculated, chart-only pseudo-sensor with no live
      # scalar reading; it must not surface as a spurious "never seen" null in
      # the default set, and an explicit request is rejected rather than
      # returning an ambiguous null.
      data = Sensor::Data::Single.new({}, timeframe: Timeframe.now, times: {})
      allow(Sensor::Query::Latest).to receive(:new).and_return(
        instance_double(Sensor::Query::Latest, call: data),
      )

      default = described_class.call(server_context: nil)
      default_names =
        JSON.parse(default.content.first[:text], symbolize_names: true)[:values].pluck(:name)
      expect(default_names).not_to include('power_balance')

      explicit =
        described_class.call(server_context: nil, sensors: ['power_balance'])
      expect(explicit.error?).to be(true)
      expect(explicit.content.first[:text]).to include('power_balance')
    end

    it 'rejects money sensors as having no live reading' do
      # Money sensors (costs, revenue) are accumulated amounts, not live
      # scalars; get_totals is the right tool for them.
      response =
        described_class.call(server_context: nil, sensors: ['solar_price'])

      expect(response.error?).to be(true)
      expect(response.content.first[:text]).to include('get_totals')
    end

    it 'reports unknown or unconfigured sensors' do
      response = described_class.call(server_context: nil, sensors: ['nonexistent'])

      expect(response.error?).to be(true)
      expect(response.content.first[:text]).to include('Unknown or unconfigured')
    end

    describe 'freshness metadata' do
      it 'reports the timestamp of a recent reading, without its age' do
        seen = 4.seconds.ago
        data =
          Sensor::Data::Single.new(
            { battery_soc: 50.0 },
            timeframe: Timeframe.now,
            times: { battery_soc: seen },
          )
        allow(Sensor::Query::Latest).to receive(:new).with([:battery_soc]).and_return(
          instance_double(Sensor::Query::Latest, call: data),
        )

        response = described_class.call(server_context: nil, sensors: ['battery_soc'])
        parsed = JSON.parse(response.content.first[:text], symbolize_names: true)
        value = parsed[:values].first

        expect(value[:last_seen_at]).to eq(seen.iso8601)
        # A reported value is fresh by construction, so its age is left out.
        expect(value).not_to have_key(:age_seconds)
      end

      it 'keeps the last_seen_at of a value dropped as too old' do
        # The live query drops stale values (null payload) but keeps the
        # timestamp, so a null value still reports when it was last seen.
        seen = 2.hours.ago
        data =
          Sensor::Data::Single.new(
            {},
            timeframe: Timeframe.now,
            times: { battery_soc: seen },
          )
        allow(Sensor::Query::Latest).to receive(:new).with([:battery_soc]).and_return(
          instance_double(Sensor::Query::Latest, call: data),
        )

        response = described_class.call(server_context: nil, sensors: ['battery_soc'])
        value = JSON.parse(response.content.first[:text], symbolize_names: true)[:values].first

        expect(value[:value]).to be_nil
        expect(value[:last_seen_at]).to eq(seen.iso8601)
        expect(value[:age_seconds]).to be > 3600
      end

      # Regression: a sensor that writes only sporadically has nothing in the
      # live window, which used to be reported as "it never delivered" - while
      # get_totals happily returned energy for the very same sensor.
      it 'looks beyond the live window for a sensor that is quiet right now' do
        seen = 3.days.ago
        add_influx_point(
          name: Sensor::Config.measurement(:battery_soc),
          fields: {
            Sensor::Config.field(:battery_soc) => 42.0,
          },
          time: seen,
        )
        data = Sensor::Data::Single.new({}, timeframe: Timeframe.now, times: {})
        allow(Sensor::Query::Latest).to receive(:new).with([:battery_soc]).and_return(
          instance_double(Sensor::Query::Latest, call: data),
        )

        response = described_class.call(server_context: nil, sensors: ['battery_soc'])
        value = JSON.parse(response.content.first[:text], symbolize_names: true)[:values].first

        expect(value[:value]).to be_nil
        expect(Time.iso8601(value[:last_seen_at])).to be_within(1.second).of(seen)
        expect(value[:age_seconds]).to be > 2.days
      end

      it 'reports a calculated sensor as fresh as its newest input' do
        seen = 10.seconds.ago
        data =
          Sensor::Data::Single.new(
            { grid_import_power: 0.0, grid_export_power: 200.0, grid_power: -200.0 },
            timeframe: Timeframe.now,
            times: { grid_import_power: 1.minute.ago, grid_export_power: seen },
          )
        allow(Sensor::Query::Latest).to receive(:new).and_return(
          instance_double(Sensor::Query::Latest, call: data),
        )

        response = described_class.call(server_context: nil, sensors: ['grid_power'])
        value = JSON.parse(response.content.first[:text], symbolize_names: true)[:values].first

        expect(value[:last_seen_at]).to eq(seen.iso8601)
      end

      it 'reports null timestamps for a sensor that never delivered' do
        data =
          Sensor::Data::Single.new(
            {},
            timeframe: Timeframe.now,
            times: {},
          )
        allow(Sensor::Query::Latest).to receive(:new).with([:battery_soc]).and_return(
          instance_double(Sensor::Query::Latest, call: data),
        )

        response = described_class.call(server_context: nil, sensors: ['battery_soc'])
        value = JSON.parse(response.content.first[:text], symbolize_names: true)[:values].first

        expect(value[:value]).to be_nil
        expect(value[:last_seen_at]).to be_nil
        expect(value[:age_seconds]).to be_nil
      end
    end

    # The tool description promises these two nulls are deliberate guards
    # against reporting noise as a number, not a missing source. Pinned here so
    # the contract and the calculation cannot drift apart - and so nobody
    # "fixes" a guard that is doing its job.
    describe 'deliberate null guards' do
      it 'suppresses self_consumption_quote below 50 W of generation' do
        quote = Sensor::Registry[:self_consumption_quote]

        # 31 W generated, 31 W self-consumed is not a meaningful 100 %.
        expect(quote.calculate(self_consumption: 31, inverter_power: 31)).to be_nil
        expect(quote.calculate(self_consumption: 100, inverter_power: 100)).to eq(100)
      end

      it 'suppresses inverter_power_difference below 5 W' do
        difference = Sensor::Registry[:inverter_power_difference]

        # 31 W against 32 W is sampling skew between two sensors, not a loss.
        expect(difference.calculate(inverter_power: 31, inverter_power_total: 32)).to be_nil
        expect(difference.calculate(inverter_power: 1000, inverter_power_total: 900)).to eq(100)
      end

      it 'suppresses inverter_power_difference below 1 % of generation' do
        difference = Sensor::Registry[:inverter_power_difference]

        expect(
          difference.calculate(inverter_power: 10_000, inverter_power_total: 9_950),
        ).to be_nil
      end
    end
  end
end
