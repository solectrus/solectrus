describe McpServer::Tools::Totals do
  before do
    create_summary(date: '2024-06-15', values: [[:house_power, :sum, 12_345]])
  end

  describe '.call' do
    it 'returns totals for a day from the PostgreSQL summaries' do
      response =
        described_class.call(
          server_context: nil,
          timeframe: '2024-06-15',
          sensors: ['house_power'],
        )

      expect(response.error?).to be(false)
      data = JSON.parse(response.content.first[:text], symbolize_names: true)
      total = data[:totals].find { _1[:name] == 'house_power' }
      expect(total[:value]).to eq(12_345.0)
      # Summing a watt sensor integrates over time -> energy, so the reported
      # unit is watt-hours, not watts (BUG-3).
      expect(total[:aggregation]).to eq('sum')
      expect(total[:unit]).to eq('watt_hour')
    end

    it 'keeps the base watt unit for non-sum aggregations' do
      # Only summing a watt sensor yields energy; avg/min/max stay watts.
      helper = ->(agg) { McpServer::Tools::Base.__send__(:mcp_unit, Sensor::Registry[:house_power], agg) }
      expect(helper.call(:sum)).to eq(:watt_hour)
      expect(helper.call(:max)).to eq(:watt)
      expect(helper.call(:avg)).to eq(:watt)
    end

    it 'reports specific_yield as a per-kWp unit, not plain watts' do
      # specific_yield is a power normalized by installed capacity (W/kWp);
      # summed it becomes a specific energy yield (Wh/kWp). The domain keeps
      # :watt, but MCP must report the honest physical unit.
      helper = ->(agg) { McpServer::Tools::Base.__send__(:mcp_unit, Sensor::Registry[:specific_yield], agg) }
      expect(helper.call(nil)).to eq(:watt_per_kwp)
      expect(helper.call(:sum)).to eq(:watt_hour_per_kwp)
      expect(helper.call(:max)).to eq(:watt_per_kwp)
    end

    it 'reports money as a currency-neutral unit, not "euro"' do
      # The money unit is currency-neutral; the real currency is configurable
      # and lives in get_system_info, so the unit must never name a currency.
      unit = McpServer::Tools::Base.__send__(:mcp_unit, Sensor::Registry[:grid_costs], :sum)
      expect(unit).to eq(:money)
    end

    it 'reports an invalid timeframe' do
      response =
        described_class.call(
          server_context: nil,
          timeframe: 'not-a-timeframe',
          sensors: ['house_power'],
        )

      expect(response.error?).to be(true)
      expect(response.content.first[:text]).to include('not a valid timeframe')
    end

    it 'reports an unknown sensor' do
      response =
        described_class.call(
          server_context: nil,
          timeframe: '2024-06-15',
          sensors: ['nonexistent'],
        )

      expect(response.error?).to be(true)
      expect(response.content.first[:text]).to include('Unknown or unconfigured')
    end

    # A null value alone reads like a sensor outage. These two timeframes
    # cannot hold data by construction, and saying so is what lets a model
    # answer "not yet" or "not back then" instead of "no data".
    describe 'a timeframe that cannot hold data' do
      def note_for(timeframe)
        response =
          described_class.call(server_context: nil, timeframe:, sensors: ['house_power'])
        JSON.parse(response.content.first[:text], symbolize_names: true)[:timeframe_note]
      end

      it 'explains a timeframe entirely in the future' do
        expect(note_for((Date.current + 1.year).strftime('%Y-%m'))).to include('future')
      end

      it 'points at get_forecast for a future timeframe' do
        expect(note_for((Date.current + 1.year).strftime('%Y-%m'))).to include('get_forecast')
      end

      it 'explains a timeframe before the installation date' do
        installation = Rails.configuration.x.installation_date

        expect(note_for((installation - 1.year).strftime('%Y-%m'))).to include(
          'installation date',
          installation.iso8601,
        )
      end

      it 'stays silent for a timeframe that can hold data' do
        expect(note_for('2024-06-15')).to be_nil
      end
    end

    describe 'an invalid timeframe' do
      # "'letzte Woche' is not a valid timeframe" told a client that it was
      # wrong but not what right looks like.
      it 'states the accepted forms' do
        response =
          described_class.call(
            server_context: nil,
            timeframe: 'letzte Woche',
            sensors: ['house_power'],
          )

        expect(response.error?).to be(true)
        expect(response.content.first[:text]).to include(
          'not a valid timeframe',
          'Accepted:',
          '"2026-W25"',
          '"all"',
        )
      end

      # A range with its dates the wrong way round is a different mistake, and
      # listing the forms there would just bury the actual reason.
      it 'leaves an inverted range error alone' do
        response =
          described_class.call(
            server_context: nil,
            timeframe: '2024-06-15..2024-06-01',
            sensors: ['house_power'],
          )

        expect(response.content.first[:text]).to include('must be AFTER')
        expect(response.content.first[:text]).not_to include('Accepted:')
      end
    end

    # conventions.suffixes asks a client to form _pv/_grid names itself and
    # calls such a name "a good guess, not a guarantee". A guess that misses
    # therefore costs its own entry, not the whole call - three requested
    # sensors of which one is a typo are still two answers.
    describe 'an unknown sensor name' do
      def response_for(*sensors)
        described_class.call(
          server_context: nil,
          timeframe: '2024-06-15',
          sensors:,
        )
      end

      it 'answers the valid sensors and reports the unknown one' do
        response = response_for('house_power', 'hause_power')

        expect(response.error?).to be(false)
        data = JSON.parse(response.content.first[:text], symbolize_names: true)
        expect(data[:totals].pluck(:name)).to eq(%w[house_power])
        expect(data[:unknown_sensors]).to eq(%w[hause_power])
      end

      it 'stays silent about unknown sensors when every name resolved' do
        response = response_for('house_power')
        data = JSON.parse(response.content.first[:text], symbolize_names: true)

        expect(data).not_to include(:unknown_sensors)
      end

      # A request where nothing is left to answer is still an error, and the
      # error has to say where the valid names are: the client cannot tell a
      # typo from a sensor this instance simply does not have.
      it 'fails when no name is left' do
        response = response_for('hause_power')

        expect(response.error?).to be(true)
        expect(response.content.first[:text]).to include(
          'Unknown or unconfigured sensors: hause_power.',
          'list_sensors',
        )
      end
    end

    it 'rejects forecast sensors and points to get_forecast' do
      response =
        described_class.call(
          server_context: nil,
          timeframe: "#{Date.current + 1}..#{Date.current + 3}",
          sensors: ['inverter_power_forecast'],
        )

      expect(response.error?).to be(true)
      text = response.content.first[:text]
      expect(text).to include('get_forecast')
      expect(text).to include('not')
    end

    context 'with the derived self_consumption sensor' do
      before do
        create_summary(
          date: '2024-06-15',
          values: [
            [:inverter_power, :sum, 50_000],
            [:grid_export_power, :sum, 30_000],
          ],
        )
      end

      # self_consumption = inverter_power - grid_export_power = 20_000
      def self_consumption_for(sensors)
        response =
          described_class.call(
            server_context: nil,
            timeframe: '2024-06-15',
            sensors:,
          )
        expect(response.error?).to be(false)
        data = JSON.parse(response.content.first[:text], symbolize_names: true)
        data[:totals].find { _1[:name] == 'self_consumption' }[:value]
      end

      it 'returns the same value regardless of which sensors are co-requested' do
        expect(self_consumption_for(%w[self_consumption])).to eq(20_000.0)
        expect(
          self_consumption_for(%w[self_consumption self_consumption_quote]),
        ).to eq(20_000.0)
        expect(
          self_consumption_for(
            %w[self_consumption inverter_power grid_export_power],
          ),
        ).to eq(20_000.0)
      end
    end

    it 'returns nil instead of raising for aggregation-less sensors only' do
      # power_balance is a calculated, chart-only pseudo-sensor with no natural
      # aggregation. Requesting it alone must not collapse the query to an empty
      # sensor list and raise "Sensor names cannot be empty".
      response =
        described_class.call(
          server_context: nil,
          timeframe: '2024-06-15',
          sensors: ['power_balance'],
        )

      expect(response.error?).to be(false)
      data = JSON.parse(response.content.first[:text], symbolize_names: true)
      total = data[:totals].find { _1[:name] == 'power_balance' }
      expect(total[:value]).to be_nil
    end

    it 'rounds every percent-unit sensor consistently to one decimal' do
      create_summary(
        date: '2024-06-15',
        values: [
          [:inverter_power, :sum, 50_000],
          [:grid_export_power, :sum, 30_000],
          [:grid_import_power, :sum, 7_000],
          [:house_power, :sum, 27_000],
        ],
      )

      response =
        described_class.call(
          server_context: nil,
          timeframe: '2024-06-15',
          sensors: %w[autarky self_consumption_quote grid_quote],
        )

      expect(response.error?).to be(false)
      data = JSON.parse(response.content.first[:text], symbolize_names: true)
      percent_totals = data[:totals].select { _1[:unit] == 'percent' }
      expect(percent_totals.size).to eq(3)

      # All percent sensors share one rounding, decided by the unit alone -
      # regardless of whether the sensor's own calculation already rounded. So
      # each value survives being rounded to one decimal again, and each is a
      # Float, never an Integer that would read as "unrounded".
      percent_totals.each do |total|
        expect(total[:value]).to eql(total[:value].round(1))
      end

      # grid_quote raw = 7000 * 100 / 27000 = 25.925..., rounded to 25.9 by the
      # response layer (its own calculation does not round).
      grid_quote = percent_totals.find { _1[:name] == 'grid_quote' }
      expect(grid_quote[:value]).to eq(25.9)
    end
  end
end
