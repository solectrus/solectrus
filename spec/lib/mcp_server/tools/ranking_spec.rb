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
