describe McpServer::Tools::Periods do
  def call(**args)
    response = described_class.call(server_context: nil, **args)
    data = JSON.parse(response.content.first[:text], symbolize_names: true)
    data[:results]&.each { |result| result[:entries] = expand(result, data[:period]) }
    [response.error?, data]
  end

  def error_for(**args)
    response = described_class.call(server_context: nil, **args)
    expect(response.error?).to be(true)
    response.content.first[:text]
  end

  # Rebuilds the {date, value} list the compact axis describes - exactly the
  # arithmetic a client performs, so the expectations below stay about
  # behaviour rather than about serialization.
  def expand(result, period)
    return [] if result[:values].blank?

    start = Date.parse(result[:start].to_s)
    partial = result[:partial_at] || []

    result[:values].each_with_index.map do |value, i|
      date = (start + i.public_send(period.to_s)).iso8601

      { date:, value:, **(partial.include?(date) ? { partial: true } : {}) }
    end
  end

  def entries(**args)
    _error, data = call(sensors: ['house_power'], **args)
    data[:results].first[:entries]
  end

  before do
    create_summary(date: '2024-01-15', values: [[:house_power, :sum, 25_000]])
    create_summary(date: '2024-01-16', values: [[:house_power, :sum, 14_000]])
    create_summary(date: '2024-01-17', values: [[:house_power, :sum, 30_000]])
  end

  let(:range) { '2024-01-15..2024-01-17' }

  describe '.call' do
    it 'returns the periods in date order' do
      error, data = call(sensors: ['house_power'], timeframe: range)

      expect(error).to be(false)
      result = data[:results].first
      expect(result[:sensor]).to eq('house_power')
      # Summed over the period, so a watt sensor reports the energy it became.
      expect(result[:aggregation]).to eq('sum')
      expect(result[:unit]).to eq('watt_hour')
      expect(result[:entries]).to eq(
        [
          { date: '2024-01-15', value: 25_000.0 },
          { date: '2024-01-16', value: 14_000.0 },
          { date: '2024-01-17', value: 30_000.0 },
        ],
      )
    end

    it 'answers several sensors in one call' do
      create_summary(
        date: '2024-01-15',
        values: [[:house_power, :sum, 25_000], [:inverter_power, :sum, 40_000]],
      )

      _error, data = call(sensors: %w[house_power inverter_power], timeframe: range)

      expect(data[:results].pluck(:sensor)).to eq(%w[house_power inverter_power])
    end

    # Which of the two a period wants follows from the unit, not from the
    # client: summing a percentage would report an autarky of 2400 %.
    it 'averages a temperature where it sums an energy' do
      create_summary(
        date: '2024-01-15',
        values: [[:house_power, :sum, 25_000], [:outdoor_temp, :avg, 18]],
      )
      create_summary(
        date: '2024-01-16',
        values: [[:house_power, :sum, 14_000], [:outdoor_temp, :avg, 22]],
      )

      _error, data =
        call(
          sensors: %w[house_power outdoor_temp],
          timeframe: '2024-01-15..2024-01-16',
          period: 'month',
        )

      expect(data[:results].map { it.values_at(:aggregation, :unit) }).to eq(
        [%w[sum watt_hour], %w[avg celsius]],
      )
      expect(data[:results].pluck(:values)).to eq([[39_000.0], [20.0]])
    end

    # A derived sensor never reaches the query's `raw_data` under its own name:
    # what lands there are its dependencies, and the sensor itself arrives
    # through the accessor Query::Base installs. Read out of raw_data instead,
    # every ratio and every cost came back null while get_totals answered a
    # number for the same period - a hole this suite missed until the tool was
    # pointed at a live instance, because every sensor tested here was stored.
    describe 'a sensor computed in SQL' do
      # March and April, clear of the January days the outer setup fills.
      before do
        create_summary(
          date: '2024-03-15',
          values: [[:house_power, :sum, 25_000], [:grid_import_power, :sum, 5_000]],
        )
        create_summary(
          date: '2024-04-20',
          values: [[:house_power, :sum, 20_000], [:grid_import_power, :sum, 10_000]],
        )
      end

      it 'reports the ratio, not a null' do
        _error, data =
          call(sensors: ['autarky'], timeframe: '2024-03-01..2024-04-30', period: 'month')
        result = data[:results].first

        expect(result[:unit]).to eq('percent')
        # (25 - 5) / 25 = 80 %, then (20 - 10) / 20 = 50 %.
        expect(result[:values]).to eq([80.0, 50.0])
      end

      # The number a client would otherwise have to reconcile by hand.
      it 'agrees with get_totals over the same period' do
        _error, data = call(sensors: ['autarky'], timeframe: '2024-03', period: 'month')

        totals =
          McpServer::Tools::Totals.call(
            server_context: nil,
            timeframe: '2024-03',
            sensors: ['autarky'],
          )
        expected = JSON.parse(totals.content.first[:text], symbolize_names: true)

        expect(data[:results].first[:values]).to eq([expected[:totals].first[:value]])
      end
    end

    # The promise the whole tool rests on. Read as a curve, a period that
    # silently dropped out is indistinguishable from one that measured zero -
    # and the client only finds out by diffing the dates itself.
    describe 'the dense list' do
      it 'reports a day without data as a null' do
        expect(entries(timeframe: '2024-01-15..2024-01-20')).to eq(
          [
            { date: '2024-01-15', value: 25_000.0 },
            { date: '2024-01-16', value: 14_000.0 },
            { date: '2024-01-17', value: 30_000.0 },
            { date: '2024-01-18', value: nil },
            { date: '2024-01-19', value: nil },
            { date: '2024-01-20', value: nil },
          ],
        )
      end

      it 'reports a month without data as a null' do
        create_summary(date: '2024-04-10', values: [[:house_power, :sum, 12_000]])

        expect(entries(timeframe: '2024-01-01..2024-04-30', period: 'month')).to eq(
          [
            { date: '2024-01-01', value: 69_000.0 },
            { date: '2024-02-01', value: nil },
            { date: '2024-03-01', value: nil },
            { date: '2024-04-01', value: 12_000.0 },
          ],
        )
      end

      # The grouped query pads day, month and year itself but not week, so
      # this is the case that proves the padding is this tool's promise rather
      # than a detail two layers down.
      it 'reports a week without data as a null' do
        expect(entries(timeframe: '2024-01-08..2024-02-04', period: 'week')).to eq(
          [
            { date: '2024-01-08', value: nil },
            { date: '2024-01-15', value: 69_000.0 },
            { date: '2024-01-22', value: nil },
            { date: '2024-01-29', value: nil },
          ],
        )
      end

      # Padded across the whole timeframe, not merely between the first and the
      # last row: a client asking for a range gets that range back, so an empty
      # start is visible instead of shifting the curve leftwards.
      it 'pads before the first period that has data' do
        expect(entries(timeframe: '2024-01-13..2024-01-17').first).to eq(
          { date: '2024-01-13', value: nil },
        )
      end

      # Dense by construction, so entry i is always at offset i and the field
      # that would say otherwise has nothing to say.
      it 'never sends indices' do
        _error, data = call(sensors: ['house_power'], timeframe: '2024-01-15..2024-01-20')

        expect(data[:results].first).not_to have_key(:indices)
      end
    end

    describe 'periods the timeframe cuts short' do
      it 'flags a month the timeframe starts inside' do
        expect(entries(timeframe: '2024-01-10..2024-03-31', period: 'month').first).to eq(
          # January, but only from the 10th: the 15th to the 17th, not the month.
          { date: '2024-01-01', value: 69_000.0, partial: true },
        )
      end

      it 'leaves a period the timeframe covers whole unflagged' do
        expect(entries(timeframe: '2024-01-01..2024-01-31', period: 'month')).to eq(
          [{ date: '2024-01-01', value: 69_000.0 }],
        )
      end

      # The regression this tool exists for. get_ranking drops a cut period so
      # that a fragment cannot win, which on a time axis deleted the newest
      # entry: a curve of monthly means ended with LAST month, and nothing
      # said the current one had been left out.
      context 'with the period still running' do
        before { create_summary(date: Date.current, values: [[:outdoor_temp, :avg, 21]]) }

        def curve
          _error, data =
            call(sensors: ['outdoor_temp'], period: 'month', timeframe: 'year')
          data[:results].first
        end

        it 'ends with the month still running, flagged' do
          expect(curve[:entries].last).to eq(
            date: Date.current.beginning_of_month.iso8601,
            value: 21.0,
            partial: true,
          )
        end

        it 'never claims to be narrowed to whole periods' do
          expect(curve).not_to have_key(:complete_periods_only)
        end

        # get_totals says it in a `timeframe_note`, having no entry to mark.
        # Here every entry carries the answer.
        it 'says it on the entry rather than in a note' do
          _error, data = call(sensors: ['house_power'], timeframe: 'month')

          expect(data).not_to have_key(:timeframe_note)
        end
      end
    end

    # A ranking shortened to five entries is still a top-5; a curve cut to its
    # first 400 points plots as a whole one. So this refuses where get_ranking
    # shortens, following get_series instead.
    describe 'a request over the entry budget' do
      let(:budget) { described_class::MAX_ENTRIES }

      it 'refuses rather than truncating' do
        expect(error_for(sensors: ['house_power'], timeframe: 'all', period: 'day')).to include(
          budget.to_s,
          'refused',
        )
      end

      it 'names the finest period that would fit' do
        expect(
          error_for(sensors: ['house_power'], timeframe: 'all', period: 'day'),
        ).to match(/Ask for period "(week|month|year)" \(\d+ periods\)/)
      end

      it 'counts the sensors into the budget' do
        # Supported by get_periods, so the budget is what rejects the call -
        # a sensor the tool has no per-period value for would be refused first.
        sensors =
          Sensor::Config
            .sensors
            .select { McpServer::SupportedTools.supports?(it, :periods) }
            .take(20)
            .map! { it.name.to_s }

        # 36 months fit comfortably for one sensor and not at all for twelve,
        # so any count above that proves the multiplication rather than the
        # timeframe. Stated as a count instead of assumed, because the
        # configured sensors are process state other specs rewrite.
        expect(sensors.size).to be >= 12

        expect(
          error_for(sensors:, timeframe: '2022-01-01..2024-12-31', period: 'month'),
        ).to include("#{sensors.size * 36} entries", "36 periods x #{sensors.size} sensor(s)")
      end

      it 'answers the same range at a period that fits' do
        error, _data = call(sensors: ['house_power'], timeframe: 'all', period: 'year')

        expect(error).to be(false)
      end
    end

    # An hour window has no calendar periods inside it, and the grouped query
    # would reach the InfluxDB half of Sensor::Query::Total, whose DSL carries
    # no `group_by` at all - a NoMethodError where the client deserves a
    # sentence.
    describe 'a timeframe of hours' do
      it 'is rejected with what to ask instead' do
        %w[P24H now].each do |timeframe|
          expect(error_for(sensors: ['house_power'], timeframe:)).to include(
            'holds no whole days',
            'get_series',
          )
        end
      end
    end

    context 'with invalid input' do
      it 'rejects a sensor with no aggregation at all' do
        expect(error_for(sensors: ['system_status'], timeframe: '2024')).to include(
          'get_periods has no per-period value',
          'no aggregation at all',
        )
      end

      # get_periods is get_totals grouped, so it rejects a forecast sensor for
      # the same reason and points at the same tool.
      it 'rejects a forecast sensor' do
        expect(
          error_for(sensors: ['inverter_power_forecast'], timeframe: '2024'),
        ).to include('get_periods has no per-period value', 'get_forecast')
      end

      it 'reports an unknown sensor' do
        expect(error_for(sensors: ['nonexistent'], timeframe: '2024')).to include(
          'Unknown or unconfigured',
        )
      end

      it 'reports an invalid timeframe' do
        expect(error_for(sensors: ['house_power'], timeframe: 'not-a-timeframe')).to include(
          'not a valid timeframe',
        )
      end

      # Skipped rather than fatal, like everywhere else: the good name is
      # answered and the typo comes back by name.
      it 'skips an unknown name beside a good one' do
        _error, data = call(sensors: %w[house_power nonexistent], timeframe: range)

        expect(data[:unknown_sensors]).to eq(%w[nonexistent])
        expect(data[:results].pluck(:sensor)).to eq(%w[house_power])
      end
    end
  end
end
