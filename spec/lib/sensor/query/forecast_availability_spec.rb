describe Sensor::Query::ForecastAvailability do
  subject(:checker) do
    described_class.new(:inverter_power_forecast, :outdoor_temp_forecast)
  end

  let(:query_api) { double('QueryApi') }

  before { allow(InfluxClient).to receive(:query_api).and_return(query_api) }

  describe '#call' do
    context 'when sensors have complete forecast data' do
      before do
        # Max timestamp at 18:00 (after 16:00 cutoff)
        max_time = (Date.current + 6.days).in_time_zone.change(hour: 18)
        record = double(values: { '_time' => max_time.iso8601 })
        table = double(records: [record])
        allow(query_api).to receive(:query).and_return([table])
      end

      it 'returns the date of the max timestamp' do
        result = checker.call
        expect(result).to eq(Date.current + 6.days)
      end
    end

    context 'when last day has incomplete data (before 16:00)' do
      before do
        # Max timestamp at 14:00 (before 16:00 cutoff)
        max_time = (Date.current + 6.days).in_time_zone.change(hour: 14)
        record = double(values: { '_time' => max_time.iso8601 })
        table = double(records: [record])
        allow(query_api).to receive(:query).and_return([table])
      end

      it 'returns the previous day' do
        result = checker.call
        expect(result).to eq(Date.current + 5.days)
      end
    end

    context 'when no forecast data available' do
      before { allow(query_api).to receive(:query).and_return([]) }

      it 'returns nil' do
        result = checker.call
        expect(result).to be_nil
      end
    end

    context 'when limit is specified' do
      before do
        # Max timestamp 10 days in the future
        max_time = (Date.current + 10.days).in_time_zone.change(hour: 18)
        record = double(values: { '_time' => max_time.iso8601 })
        table = double(records: [record])
        allow(query_api).to receive(:query).and_return([table])
      end

      it 'clamps to the limit' do
        result = checker.call(limit: 7.days)
        expect(result).to eq(Date.current + 7.days)
      end
    end

    it 'uses caching' do
      max_time = (Date.current + 2.days).in_time_zone.change(hour: 18)
      record = double(values: { '_time' => max_time.iso8601 })
      table = double(records: [record])
      allow(query_api).to receive(:query).and_return([table])

      # First call should query
      result1 = checker.call
      expect(result1).to eq(Date.current + 2.days)

      # Second call should use cache
      result2 = checker.call
      expect(result2).to eq(Date.current + 2.days)
    end
  end
end
