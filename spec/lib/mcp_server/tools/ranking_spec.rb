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
