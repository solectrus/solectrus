describe Sensor::Query::ForecastAvailability do
  subject(:checker) do
    described_class.new(:inverter_power_forecast, :outdoor_temp_forecast)
  end

  # Influx.query returns plain row hashes (see Influx::CsvParser)
  def stub_max_time(time)
    allow(Influx).to receive(:query).and_return([{ '_time' => time.iso8601 }])
  end

  describe '#call' do
    context 'when sensors have complete forecast data' do
      # Max timestamp at 18:00 (after 16:00 cutoff)
      before { stub_max_time((Date.current + 6.days).in_time_zone.change(hour: 18)) }

      it 'returns the date of the max timestamp' do
        result = checker.call
        expect(result).to eq(Date.current + 6.days)
      end
    end

    context 'when last day has incomplete data (before 16:00)' do
      # Max timestamp at 14:00 (before 16:00 cutoff)
      before { stub_max_time((Date.current + 6.days).in_time_zone.change(hour: 14)) }

      it 'returns the previous day' do
        result = checker.call
        expect(result).to eq(Date.current + 5.days)
      end
    end

    context 'when no forecast data available' do
      before { allow(Influx).to receive(:query).and_return([]) }

      it 'returns nil' do
        result = checker.call
        expect(result).to be_nil
      end
    end

    context 'when limit is specified' do
      # Max timestamp 10 days in the future
      before { stub_max_time((Date.current + 10.days).in_time_zone.change(hour: 18)) }

      it 'clamps to the limit' do
        result = checker.call(limit: 7.days)
        expect(result).to eq(Date.current + 7.days)
      end
    end

    context 'with an active cache' do
      before do
        allow(Rails).to receive(:cache).and_return(
          ActiveSupport::Cache::MemoryStore.new,
        )
      end

      it 'caches a positive result' do
        stub_max_time((Date.current + 2.days).in_time_zone.change(hour: 18))
        2.times { checker.call }

        expect(Influx).to have_received(:query).once
      end

      it 'does not cache a missing forecast' do
        allow(Influx).to receive(:query).and_return([])
        2.times { checker.call }

        expect(Influx).to have_received(:query).twice
      end
    end
  end
end
