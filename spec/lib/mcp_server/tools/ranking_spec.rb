describe McpServer::Tools::Ranking do
  def call(**args)
    response = described_class.call(**args)
    [response.error?, JSON.parse(response.content.first[:text], symbolize_names: true)]
  end

  before do
    create_summary(date: '2024-01-15', values: [[:house_power, :sum, 25_000]])
    create_summary(date: '2024-01-16', values: [[:house_power, :sum, 14_000]])
    create_summary(date: '2024-01-17', values: [[:house_power, :sum, 30_000]])
  end

  let(:range) { '2024-01-01..2024-01-31' }

  describe '.call' do
    it 'ranks days descending by default' do
      error, data = call(sensor: 'house_power', timeframe: range)

      expect(error).to be(false)
      result = data[:results].first
      expect(result[:sensor]).to eq('house_power')
      expect(result[:aggregation]).to eq('sum')
      # A summed watt sensor ranks energies, so the unit is watt-hours (BUG-3).
      expect(result[:unit]).to eq('watt_hour')
      expect(result[:ranking].pluck(:date)).to eq(
        %w[2024-01-17 2024-01-15 2024-01-16],
      )
      expect(result[:ranking].first[:value]).to eq(30_000.0)
    end

    it 'ranks ascending when requested' do
      _error, data = call(sensor: 'house_power', timeframe: range, order: 'asc')

      expect(data[:results].first[:ranking].first[:date]).to eq('2024-01-16')
    end

    it 'sorts chronologically when requested' do
      _error, data =
        call(sensor: 'house_power', timeframe: range, sort: 'chronological')

      expect(data[:results].first[:ranking].pluck(:date)).to eq(
        %w[2024-01-15 2024-01-16 2024-01-17],
      )
    end

    # A day without data has no summary row, so it used to vanish from a
    # chronological list without a trace - the client had to spot the date gap
    # itself and then confirm with get_totals that it really means "no data"
    # rather than an artefact of the sorting.
    context 'with a day that has no data at all' do
      before { create_summary(date: '2024-01-20', values: [[:house_power, :sum, 12_000]]) }

      def ranking(**args)
        _error, data =
          call(sensor: 'house_power', timeframe: range, sort: 'chronological', limit: 50, **args)
        data[:results].first[:ranking]
      end

      # The 18th and 19th have no summary row at all; the timeframe spans all
      # of January, but nothing is padded outside the data's own range.
      it 'reports the missing days with a null value' do
        expect(ranking.pluck(:date)).to eq(
          %w[
            2024-01-15
            2024-01-16
            2024-01-17
            2024-01-18
            2024-01-19
            2024-01-20
          ],
        )
        expect(ranking.pluck(:value)).to eq([25_000.0, 14_000.0, 30_000.0, nil, nil, 12_000.0])
      end

      it 'leaves a list truncated by the limit alone' do
        # With limit: 4 the four days with data fill the list, so a missing day
        # cannot be told from one that did not make the cut.
        expect(ranking(limit: 4).pluck(:value)).to all(be_present)
      end

      it 'keeps a value ranking free of periods without data' do
        _error, data =
          call(sensor: 'house_power', timeframe: range, sort: 'value', limit: 50)

        expect(data[:results].first[:ranking].pluck(:value)).to all(be_present)
      end
    end

    context 'with a month that has no data at all' do
      before { create_summary(date: '2024-04-10', values: [[:house_power, :sum, 12_000]]) }

      it 'reports the missing months with a null value' do
        _error, data =
          call(
            sensor: 'house_power',
            timeframe: '2024-01-01..2024-04-30',
            period: 'month',
            sort: 'chronological',
            limit: 50,
          )

        expect(data[:results].first[:ranking]).to eq(
          [
            { date: '2024-01-01', value: 69_000.0 },
            { date: '2024-02-01', value: nil },
            { date: '2024-03-01', value: nil },
            { date: '2024-04-01', value: 12_000.0 },
          ],
        )
      end
    end

    # A ranked period is labelled with its start but summed over the days the
    # timeframe actually covers, so an edge period can be a fragment under a
    # label claiming the whole month/week/year. Unflagged, it competes against
    # whole periods in the same list - and wins an ascending ranking for the
    # wrong reason.
    describe 'periods the timeframe cuts short' do
      def ranking(**args)
        _error, data = call(sensor: 'house_power', sort: 'chronological', limit: 50, **args)
        data[:results].first[:ranking]
      end

      it 'flags a month the timeframe starts inside' do
        expect(ranking(timeframe: '2024-01-10..2024-03-31', period: 'month').first).to eq(
          # January, but only from the 10th: the 15th to the 17th, not the month.
          { date: '2024-01-01', value: 69_000.0, partial: true },
        )
      end

      it 'flags a month the timeframe ends inside' do
        create_summary(date: '2024-03-05', values: [[:house_power, :sum, 5_000]])

        expect(ranking(timeframe: '2024-01-01..2024-03-10', period: 'month').last).to eq(
          { date: '2024-03-01', value: 5_000.0, partial: true },
        )
      end

      # The week holding New Year starts in the previous year (1 Jan 2025 is a
      # Wednesday), so its date can even fall outside the timeframe that
      # produced it - the one case where a client could spot the fragment
      # itself, and only for a timeframe that names its dates.
      it 'flags a week reaching back before the timeframe' do
        create_summary(date: '2025-01-02', values: [[:house_power, :sum, 8_000]])

        expect(ranking(timeframe: '2025', period: 'week')).to eq(
          [{ date: '2024-12-30', value: 8_000.0, partial: true }],
        )
      end

      it 'leaves a period the timeframe covers whole unflagged' do
        expect(ranking(timeframe: '2024-01-01..2024-01-31', period: 'month')).to eq(
          [{ date: '2024-01-01', value: 69_000.0 }],
        )
      end

      it 'leaves plain days unflagged' do
        expect(ranking(timeframe: range).pluck(:partial)).to all(be_nil)
      end

      # The day still running is a fragment for a reason the timeframe bounds
      # cannot state: they are capped at today, so a period ending today never
      # looks cut by them. Left unflagged it is a few hours of measurement
      # ranked against whole days - and period="day" is the default.
      context 'with the period still running' do
        before do
          create_summary(date: Date.current, values: [[:house_power, :sum, 3_000]])
          create_summary(date: Date.yesterday, values: [[:house_power, :sum, 21_000]])
        end

        it 'flags today but not yesterday' do
          entries = ranking(timeframe: 'month').index_by { |entry| entry[:date] }

          expect(entries[Date.current.iso8601]).to include(partial: true)
          expect(entries[Date.yesterday.iso8601]).not_to include(:partial)
        end

        it 'flags the running month' do
          expect(ranking(timeframe: 'year', period: 'month').last).to include(partial: true)
        end
      end
    end

    # A single day is one of the timeframe forms the tool advertises, and a
    # ranking over it is a valid ranking with one entry. A sensor computed in
    # SQL (any ratio, any cost) re-derives a timeframe from the ranked
    # start/stop dates, and spelled that single day as the range
    # "2024-01-15..2024-01-15" - which is no range at all, and was rejected as
    # one.
    context 'with a single day as the timeframe' do
      before do
        create_summary(
          date: '2024-01-15',
          values: [
            [:house_power, :sum, 25_000],
            [:grid_import_power, :sum, 5_000],
          ],
        )
      end

      it 'ranks a stored sensor' do
        _error, data = call(sensor: 'house_power', timeframe: '2024-01-15')

        expect(data[:results].first[:ranking]).to eq(
          [{ date: '2024-01-15', value: 25_000 }],
        )
      end

      it 'ranks a sensor computed in SQL' do
        error, data = call(sensor: 'autarky', timeframe: '2024-01-15')

        expect(error).to be(false)
        expect(data[:results].first[:ranking]).to eq(
          [{ date: '2024-01-15', value: 80.0 }],
        )
      end
    end

    # A ranking that leaves the cut periods out is answering a narrower
    # question than it was asked: autarky over "2024-01-19..2024-03-10" reports
    # February alone while inverter_power reports all three months. Dropping
    # them is right - an average is not smaller for covering half a month, so a
    # fragment would win on the strength of being one - but doing it in silence
    # lets an incomplete ranking look complete.
    describe 'a ranking narrowed to whole periods' do
      before do
        %w[2024-01-20 2024-02-10 2024-03-05].each do |date|
          create_summary(
            date:,
            values: [
              [:house_power, :sum, 25_000],
              [:grid_import_power, :sum, 5_000],
              [:inverter_power, :sum, 40_000],
            ],
          )
        end
      end

      def result(**args)
        _error, data =
          call(timeframe: '2024-01-19..2024-03-10', period: 'month', limit: 50, **args)
        data[:results].first
      end

      it 'says so for an averaged ratio, in either direction' do
        %w[desc asc].each do |order|
          expect(result(sensor: 'autarky', order:)).to include(
            complete_periods_only: true,
          )
          expect(result(sensor: 'autarky', order:)[:ranking].pluck(:date)).to eq(
            %w[2024-02-01],
          )
        end
      end

      it 'says so for an ascending ranking of any sensor' do
        expect(result(sensor: 'inverter_power', order: 'asc')).to include(
          complete_periods_only: true,
        )
      end

      # The common case pays nothing, and the flag's presence is the whole
      # signal: here the cut months are ranked, carrying `partial` instead.
      it 'stays silent where every period the timeframe cuts is ranked' do
        ranked = result(sensor: 'inverter_power')

        expect(ranked).not_to include(:complete_periods_only)
        expect(ranked[:ranking].pluck(:date)).to contain_exactly(
          '2024-01-01',
          '2024-02-01',
          '2024-03-01',
        )
      end
    end

    it 'ranks multiple sensors in one call' do
      create_summary(date: '2024-01-15', values: [[:house_power, :sum, 25_000], [:inverter_power_1, :sum, 40_000]])

      _error, data =
        call(sensors: %w[house_power inverter_power_1], timeframe: range)

      expect(data[:results].pluck(:sensor)).to eq(%w[house_power inverter_power_1])
    end

    it 'clamps the limit to a minimum of 1' do
      _error, data = call(sensor: 'house_power', timeframe: range, limit: 0)

      expect(data[:results].first[:ranking].size).to eq(1)
    end

    it 'clamps the limit to a maximum of 100' do
      _error, data = call(sensor: 'house_power', timeframe: range, limit: 1_000_000)

      # All three summaries are returned, but the query was capped at 100.
      expect(data[:results].first[:ranking].size).to eq(3)
    end

    context 'with invalid input' do
      it 'requires at least one sensor' do
        response = described_class.call(timeframe: '2024')

        expect(response.error?).to be(true)
        expect(response.content.first[:text]).to include('at least one sensor')
      end

      it 'rejects more than the allowed number of sensors' do
        too_many = Sensor::Config.sensors.take(21)
        names = too_many.map { _1.name.to_s }

        response = described_class.call(sensors: names, timeframe: '2024')

        expect(response.error?).to be(true)
        expect(response.content.first[:text]).to include('Too many sensors')
      end

      it 'reports an unknown sensor' do
        response = described_class.call(sensor: 'nonexistent', timeframe: '2024')

        expect(response.error?).to be(true)
        expect(response.content.first[:text]).to include('Unknown or unconfigured')
      end

      it 'reports an invalid timeframe' do
        response =
          described_class.call(sensor: 'house_power', timeframe: 'not-a-timeframe')

        expect(response.error?).to be(true)
        expect(response.content.first[:text]).to include('not a valid timeframe')
      end

      it 'reports a sensor without a natural aggregation' do
        response = described_class.call(sensor: 'system_status', timeframe: '2024')

        expect(response.error?).to be(true)
        expect(response.content.first[:text]).to include('no natural aggregation')
      end

      it 'reports an unsupported aggregation' do
        response =
          described_class.call(
            sensor: 'house_power',
            timeframe: '2024',
            aggregation: 'avg',
          )

        expect(response.error?).to be(true)
        expect(response.content.first[:text]).to include('avg aggregation')
      end
    end
  end
end
