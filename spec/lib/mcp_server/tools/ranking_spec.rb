describe McpServer::Tools::Ranking do
  def call(**args)
    response = described_class.call(**args)
    data = JSON.parse(response.content.first[:text], symbolize_names: true)
    data[:results]&.each { |result| result[:ranking] = expand(result, data[:period]) }
    [response.error?, data]
  end

  # Rebuilds the {date, value} list the compact axis describes - exactly the
  # arithmetic a client performs. It keeps the expectations below about
  # behaviour rather than about serialization, and doubles as an executable
  # statement of what `start`/`indices`/`partial_at` mean. The format itself is
  # pinned separately, further down.
  def expand(result, period)
    return [] if result[:values].blank?

    start = Date.parse(result[:start].to_s)
    partial = result[:partial_at] || []

    result[:values].each_with_index.map do |value, i|
      index = result[:indices] ? result[:indices][i] : i
      date = (start + index.public_send(period.to_s)).iso8601

      { date:, value:, **(partial.include?(date) ? { partial: true } : {}) }
    end
  end

  before do
    create_summary(date: '2024-01-15', values: [[:house_power, :sum, 25_000]])
    create_summary(date: '2024-01-16', values: [[:house_power, :sum, 14_000]])
    create_summary(date: '2024-01-17', values: [[:house_power, :sum, 30_000]])
  end

  let(:range) { '2024-01-01..2024-01-31' }

  # Both optional axis fields reach the client, and a field it receives
  # without a word about it is a field it has to guess at. `indices` is the
  # guess that silently reorders a ranking: read as positions in `values`
  # rather than as offsets from `start`, every value ranking comes out wrong -
  # and sort="value" is the default, so it is the common answer.
  describe '.description' do
    it 'names the index space `indices` counts in' do
      _error, data = call(sensor: 'house_power', timeframe: range)

      expect(data[:results].first).to have_key(:indices)
      expect(described_class.description.squish).to include(
        '`indices`',
        'offset from it in `period` steps',
        'never a position in `values`',
      )
    end

    it 'names `partial_at`' do
      expect(described_class.description).to include('`partial_at`')
    end
  end

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

    # A ranking is a SELECTION, so a period missing from it may simply not have
    # made the cut - padding it with an explicit null would claim it holds no
    # data. That promise belongs to get_periods, which returns every period.
    it 'never pads a period without data' do
      create_summary(date: '2024-01-20', values: [[:house_power, :sum, 12_000]])

      _error, data = call(sensor: 'house_power', timeframe: range, limit: 50)

      expect(data[:results].first[:ranking].pluck(:value)).to all(be_present)
    end

    # A ranked period is labelled with its start but summed over the days the
    # timeframe actually covers, so an edge period can be a fragment under a
    # label claiming the whole month/week/year. Unflagged, it competes against
    # whole periods in the same list - and wins an ascending ranking for the
    # wrong reason.
    describe 'periods the timeframe cuts short' do
      def ranking(**args)
        _error, data = call(sensor: 'house_power', limit: 50, **args)
        data[:results].first[:ranking]
      end

      # By date, because a ranking is ordered by size: which position an entry
      # lands on is what this tool decides, not what these examples are about.
      def entry(date, **args)
        ranking(**args).find { it[:date] == date }
      end

      it 'flags a month the timeframe starts inside' do
        expect(entry('2024-01-01', timeframe: '2024-01-10..2024-03-31', period: 'month')).to eq(
          # January, but only from the 10th: the 15th to the 17th, not the month.
          { date: '2024-01-01', value: 69_000.0, partial: true },
        )
      end

      it 'flags a month the timeframe ends inside' do
        create_summary(date: '2024-03-05', values: [[:house_power, :sum, 5_000]])

        expect(entry('2024-03-01', timeframe: '2024-01-01..2024-03-10', period: 'month')).to eq(
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

      # `indices` counts PERIODS from `start`, so a partial_at counting
      # POSITIONS in `values` was a second index space in the same object - and
      # a value ranking, ordered by size, is exactly where the two disagree.
      # Here entry 1 is January while period offset 1 is February.
      it 'names the cut periods by their period start, not by their position' do
        create_summary(date: '2024-02-20', values: [[:house_power, :sum, 80_000]])

        _error, data =
          call(sensor: 'house_power', timeframe: '2024-01-10..2024-02-29', period: 'month')
        result = data[:results].first

        expect(result[:indices]).to eq([1, 0])
        expect(result[:partial_at]).to eq(%w[2024-01-01])
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
          expect(
            entry(Date.current.beginning_of_month.iso8601, timeframe: 'year', period: 'month'),
          ).to include(partial: true)
        end

        # get_totals says it in a `timeframe_note`, having no entry to mark.
        # Here every entry carries the answer, so the note would repeat per
        # call what the payload states per value.
        it 'says it on the entry rather than in a note' do
          _error, data = call(sensor: 'house_power', timeframe: 'month')

          expect(data).not_to have_key(:timeframe_note)
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

      # The rule used to be an opt-in the two ratios set and nothing else, so
      # an averaged temperature or state of charge ranked its cut months
      # against whole ones - the identical distortion, unflagged. An average is
      # not smaller for covering less, whatever the sensor measures.
      it 'says so for any averaged sensor, not just the two ratios' do
        create_summary(date: '2024-02-10', values: [[:outdoor_temp, :avg, 21]])

        expect(result(sensor: 'outdoor_temp', aggregation: 'avg')).to include(
          complete_periods_only: true,
        )
      end

      # A summed fragment is simply a smaller sum, which sorts low on its own.
      it 'stays silent for a summed sensor ranked descending' do
        expect(result(sensor: 'inverter_power', aggregation: 'sum')).not_to include(
          :complete_periods_only,
        )
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

    # Two ways to name a sensor, and the schema can only mark both optional.
    # Filling both in is answerable, so it is answered - but a client sending
    # one name in each field and reading back two results otherwise cannot tell
    # a merge from a field that was ignored.
    describe 'with both `sensors` and `sensor` given' do
      def data_for
        _error, data =
          call(sensors: ['house_power'], sensor: 'inverter_power', timeframe: range)
        data
      end

      it 'answers both, in the order it merged them' do
        expect(data_for[:results].pluck(:sensor)).to eq(%w[house_power inverter_power])
      end

      it 'says that it merged them' do
        expect(data_for[:sensors_note]).to include('MERGED', '`sensors`', '`sensor`')
      end

      it 'stays silent when only one of them is given for `sensors`' do
        _error, data = call(sensor: 'house_power', timeframe: range)

        expect(data).not_to have_key(:sensors_note)
      end
    end

    # A client works from the schema it cached, and this one used to offer
    # `sort`. Dropping the argument in silence hands such a client a ranking
    # where it asked for a curve - which looks like an answer and is the wrong
    # question.
    describe 'with the retired `sort` argument' do
      def data_for(**args)
        _error, data = call(sensor: 'house_power', timeframe: range, **args)
        data
      end

      it 'still answers, as a ranking' do
        expect(data_for(sort: 'chronological')[:results].first[:ranking].pluck(:date)).to eq(
          %w[2024-01-17 2024-01-15 2024-01-16],
        )
      end

      it 'says the argument was ignored and where the question went' do
        expect(data_for(sort: 'chronological')[:sort_note]).to include(
          '`sort` is no longer accepted',
          'get_periods',
        )
      end

      it 'stays silent when it is not sent' do
        expect(data_for).not_to have_key(:sort_note)
      end
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

    # `limit` counts per sensor, so without a shared budget a ranking was the
    # largest response this server could produce: 20 sensors at limit 100 came
    # back as 1800 entries and 65 kB, three times what get_series can cost
    # since its point budget became a hard limit. What reaches the client is
    # one context window, not one per sensor.
    context 'with the entry budget shared across sensors' do
      let(:budget) { McpServer::Tools::Ranking::MAX_ENTRIES }
      let(:sensors) do
        Sensor::Config.sensors.select(&:rankable?).take(20).map! { _1.name.to_s }
      end

      def limit_for(count, limit)
        _error, data = call(sensors: sensors.take(count), timeframe: range, limit:)
        data
      end

      it 'leaves a single sensor at the full limit' do
        expect(limit_for(1, 100)[:limit]).to eq(100)
      end

      # 400 / 4 is exactly MAX_LIMIT, so everything that was reasonable before
      # is answered unchanged.
      it 'leaves four sensors at the full limit' do
        expect(limit_for(4, 100)[:limit]).to eq(100)
      end

      it 'shortens the list once the sensors outgrow the budget' do
        data = limit_for(20, 100)

        expect(data[:limit]).to eq(budget / 20)
        expect(data[:results].sum { _1[:ranking].size }).to be <= budget
      end

      # A shortened list must not read as "the data ends here".
      it 'says why it shortened the list' do
        expect(limit_for(20, 100)[:limit_note]).to include('20 sensors', budget.to_s)
      end

      it 'stays silent where nothing was shortened' do
        expect(limit_for(20, 10)).not_to have_key(:limit_note)
      end

      it 'reports the limit it applied even then' do
        expect(limit_for(20, 10)[:limit]).to eq(10)
      end
    end

    context 'with invalid input' do
      # The schema can only mark both `sensors` and `sensor` optional, so this
      # error is the one place a client learns that one of them is required -
      # and it has to name them, or the client cannot act on it.
      it 'requires at least one sensor, naming both ways to pass one' do
        response = described_class.call(timeframe: '2024')

        expect(response.error?).to be(true)
        expect(response.content.first[:text]).to include('`sensors`', '`sensor`')
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

      # A sensor with no aggregation at all cannot be ranked by any argument:
      # `aggregation` is validated against the sensor's own (empty) list, so
      # "pass an explicit aggregation" - what this used to say - sent the
      # client into a retry that could only fail again.
      describe 'a sensor with no aggregation at all' do
        def text_for(**args)
          response = described_class.call(timeframe: '2024', **args)
          expect(response.error?).to be(true)
          response.content.first[:text]
        end

        it 'says the sensor cannot be ranked, not what to pass' do
          text = text_for(sensor: 'system_status')

          expect(text).to include('no aggregation at all', 'system_status')
          expect(text).not_to include('pass an explicit')
        end

        it 'says the same when an aggregation IS passed' do
          expect(text_for(sensor: 'system_status', aggregation: 'sum')).to include(
            'no aggregation at all',
          )
        end

        # Two different reasons a ranking is impossible, and only the more
        # specific one is actionable: pointing house_power_without_custom at
        # the summaries helps, pointing system_status at them does not.
        it 'prefers it over the "not stored in the summaries" reason' do
          expect(
            text_for(sensors: %w[system_status house_power_without_custom]),
          ).to include('no aggregation at all')
        end
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
