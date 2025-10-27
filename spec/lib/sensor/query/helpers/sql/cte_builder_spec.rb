describe Sensor::Query::Helpers::Sql::CteBuilder do
  let(:timeframe) { Timeframe.new('2025-01-15') }
  let(:required_prices) { Set.new }
  let(:required_fields) { Set.new(['inverter_power']) }
  let(:required_aggregations) { Set.new([:sum]) }

  describe '#initialize' do
    it 'initializes with required parameters' do
      sensor_requests = [%i[inverter_power sum sum]]

      builder =
        described_class.new(
          sensor_requests: sensor_requests,
          timeframe: timeframe,
          required_prices: required_prices,
          required_fields: required_fields,
          required_aggregations: required_aggregations,
        )

      expect(builder.sensor_requests).to eq(sensor_requests)
      expect(builder.timeframe).to eq(timeframe)
      expect(builder.required_prices).to eq(required_prices)
      expect(builder.required_fields).to eq(required_fields)
      expect(builder.required_aggregations).to eq(required_aggregations)
    end
  end

  describe '#build_daily_cte' do
    it 'generates correct basic CTE structure' do
      sensor_requests = [%i[inverter_power sum sum]]

      builder =
        described_class.new(
          sensor_requests: sensor_requests,
          timeframe: timeframe,
          required_prices: required_prices,
          required_fields: required_fields,
          required_aggregations: required_aggregations,
        )

      result = builder.build_daily_cte

      expect(result).to include('WITH daily AS')
      expect(result).to include('FROM summary_values sv')
      expect(result).to include('GROUP BY sv.date')
    end
  end

  describe '#build_price_cte' do
    context 'when no prices are required' do
      it 'returns nil' do
        sensor_requests = [%i[inverter_power sum sum]]

        builder =
          described_class.new(
            sensor_requests: sensor_requests,
            timeframe: timeframe,
            required_prices: Set.new,
            required_fields: required_fields,
            required_aggregations: required_aggregations,
          )

        expect(builder.build_price_cte).to be_nil
      end
    end

    context 'when prices are required' do
      it 'generates price CTE' do
        sensor_requests = [%i[traditional_costs sum sum]]
        prices_required = Set.new([:electricity])

        builder =
          described_class.new(
            sensor_requests: sensor_requests,
            timeframe: timeframe,
            required_prices: prices_required,
            required_fields: required_fields,
            required_aggregations: required_aggregations,
          )

        result = builder.build_price_cte

        expect(result).to include('WITH price_ranges AS')
        expect(result).to include('FROM prices')
        expect(result).to include("name IN ('electricity')")
      end
    end
  end
end
