describe McpServer::Tools::Totals do
  before do
    create_summary(
      date: '2024-06-15',
      values: [[:house_power, :sum, 12_345], [:inverter_power, :sum, 20_000]],
    )
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

    # co2_reduction is computed from a power, so unaggregated it is a RATE -
    # the grams avoided per hour at the current generation. Reporting that as
    # "gram" invited a client to add live readings up into a daily total.
    it 'reports co2_reduction as a rate live and as an amount once aggregated' do
      helper = ->(agg) { McpServer::Tools::Base.__send__(:mcp_unit, Sensor::Registry[:co2_reduction], agg) }
      expect(helper.call(nil)).to eq(:gram_per_hour)
      expect(helper.call(:sum)).to eq(:gram)
      expect(helper.call(:avg)).to eq(:gram)
      expect(helper.call(:max)).to eq(:gram)
    end

    it 'reports an aggregated co2_reduction in grams' do
      response =
        described_class.call(
          server_context: nil,
          timeframe: '2024-06-15',
          sensors: ['co2_reduction'],
        )

      total =
        JSON.parse(response.content.first[:text], symbolize_names: true)[:totals].first
      expect(total[:unit]).to eq('gram')
      expect(total[:value]).to be_positive
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

    # A total is one number for the whole period, and nothing in it says the
    # period is half over. "How much did I use this month?" answered against
    # last month's total therefore compares nine days with thirty-one.
    # get_ranking and get_series need no such note - they flag the running
    # period on the entry it belongs to.
    describe 'a period that has not ended yet' do
      def note_for(timeframe)
        response =
          described_class.call(server_context: nil, timeframe:, sensors: ['house_power'])
        JSON.parse(response.content.first[:text], symbolize_names: true)[:timeframe_note]
      end

      it 'says so for the running day' do
        expect(note_for('day')).to include('has not ended yet')
      end

      it 'says so for the running month and year' do
        expect(note_for('month')).to include('has not ended yet')
        expect(note_for('year')).to include('has not ended yet')
      end

      it 'stays silent for a period that is over' do
        expect(note_for('2024-06-15')).to be_nil
        expect(note_for('2024-06')).to be_nil
      end

      # A rolling window covers its full width wherever it is asked - "the last
      # 24 hours" are 24 hours, not a day that has barely started.
      it 'stays silent for a rolling window' do
        expect(note_for('P24H')).to be_nil
        expect(note_for('P30D')).to be_nil
      end

      # One response carries both kinds, and only the sums are cut short: an
      # autarky of 81 % is the mean of the hours measured so far, not a
      # percentage that grows towards midnight. "Such a value is smaller for
      # being cut short" said the wrong thing about half the payload, and a
      # client acting on it reported a full-day autarky as an understatement.
      it 'separates a summed value from an averaged one' do
        note = note_for('day')

        expect(note).to include('SUMMED', 'smaller for being cut short')
        expect(note).to include('AVERAGED', 'not smaller at all')
      end

      # The note talks about two kinds of value; the entries are what say
      # which kind each one is.
      it 'sends the aggregation it points at' do
        response =
          described_class.call(
            server_context: nil,
            timeframe: 'day',
            sensors: %w[house_power autarky],
          )
        data = JSON.parse(response.content.first[:text], symbolize_names: true)

        expect(data[:timeframe_note]).to include('`aggregation`')
        expect(data[:totals].pluck(:aggregation)).to eq(%w[sum avg])
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

      def error_for(timeframe)
        response =
          described_class.call(server_context: nil, timeframe:, sensors: ['house_power'])
        expect(response.error?).to be(true)
        response.content.first[:text]
      end

      # A range with its dates the wrong way round is a different mistake, and
      # listing the whole grammar there would bury the one string that fixes
      # it.
      it 'hands an inverted range the corrected string' do
        text = error_for('2024-06-15..2024-06-01')

        expect(text).to include('must be AFTER', '"2024-06-01..2024-06-15"')
        expect(text).not_to include('Accepted:')
      end

      # A range needs two days by definition, so "X..X" is not a shorter range
      # but the day form written the long way.
      it 'points a zero-length range at the day form' do
        text = error_for('2024-06-15..2024-06-15')

        expect(text).to include('at least two days', '"2024-06-15"')
      end

      # "P120H" is a correct FORM carrying a number the grammar does not: an
      # hour window is read from raw samples and ends at 99 hours. Answering it
      # with the whole grammar told a client that got the form right to read
      # nine forms again, and never named the number it had to change.
      it 'names the hour bound for an hour window past it' do
        text = error_for("P#{Timeframe::MAX_HOURS + 1}H")

        expect(text).to include("#{Timeframe::MAX_HOURS} hours", 'P5D')
        expect(text).not_to include('Accepted:')
      end

      it 'answers the longest hour window there is' do
        response =
          described_class.call(
            server_context: nil,
            timeframe: "P#{Timeframe::MAX_HOURS}H",
            sensors: ['house_power'],
          )

        expect(response.error?).to be(false)
      end

      # Timeframe validates by regex, so a date that cannot exist passes its
      # constructor and used to fail much later as a bare "invalid date" -
      # naming neither the argument nor what a valid one looks like.
      it 'names the argument and the forms for a date that cannot exist' do
        expect(error_for('2024-02-30')).to include(
          'not a valid timeframe',
          'Accepted:',
        )
      end

      it 'does the same for an impossible week' do
        expect(error_for('2024-W99')).to include('not a valid timeframe')
      end

      it 'does the same for an impossible date inside a range' do
        expect(error_for('2024-02-30..2024-03-05')).to include('not a valid timeframe')
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

    # A sensor with no aggregation at all has no total, ever - power_balance is
    # a chart-only composite, system_status a status text. Answering them with
    # `value: null` made "you asked the wrong tool" look exactly like "this
    # timeframe holds no data", the one thing a null here must not mean. Every
    # other tool rejects what it cannot answer, so this one does too.
    describe 'a sensor with no aggregation at all' do
      def response_for(*sensors)
        described_class.call(server_context: nil, timeframe: '2024-06-15', sensors:)
      end

      it 'rejects it by name instead of answering null' do
        response = response_for('power_balance')

        expect(response.error?).to be(true)
        expect(response.content.first[:text]).to include(
          'no aggregation at all',
          'power_balance',
        )
      end

      # The whole call fails rather than half of it: unlike an unknown name,
      # this is a sensor the instance really has, so silently dropping it would
      # answer a different question than the one asked.
      it 'rejects the call even when a valid sensor is alongside' do
        expect(response_for('house_power', 'power_balance').error?).to be(true)
      end

      it 'leaves a sensor that does have one alone' do
        expect(response_for('house_power').error?).to be(false)
      end

      # The `t` flag says exactly this now, so a client can avoid the call
      # instead of learning from the error.
      it 'is the same set the tools code marks without "t"' do
        expect(McpServer::SupportedTools.code(Sensor::Registry[:power_balance])).not_to include('t')
        expect(McpServer::SupportedTools.code(Sensor::Registry[:house_power])).to include('t')
      end
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

    # The running day has no summary until something asks for one, and a web
    # request that needs summaries builds them first. MCP renders no page, so
    # it used to be the one caller that never did: "how much did I produce
    # today?" answered null while the inverter was feeding in.
    it 'answers for the running day, which has no summary yet' do
      # Fixed midday, so the seeded hours always land inside the running day.
      travel_to Time.zone.local(2024, 6, 15, 12, 0, 0)

      influx_batch do
        6.times do |quarter|
          add_influx_point(
            name: Sensor::Config.measurement(:house_power),
            fields: {
              Sensor::Config.field(:house_power) => 2_000.0,
            },
            time: Time.current - (quarter * 15).minutes,
          )
        end
      end
      Summary.where(date: Date.current).delete_all
      expect(Summary.where(date: Date.current)).not_to exist

      response =
        described_class.call(
          server_context: nil,
          timeframe: 'day',
          sensors: ['house_power'],
        )

      total =
        JSON.parse(response.content.first[:text], symbolize_names: true)[
          :totals,
        ].first
      expect(total[:value]).to be_positive
      expect(Summary.where(date: Date.current)).to exist
    end
  end
end
