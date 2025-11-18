describe Sensor::Query::Total do
  describe 'initialization' do
    it 'requires a block' do
      expect { described_class.new(Timeframe.day) }.to raise_error(
        ArgumentError,
        'Block required for DSL configuration',
      )
    end
  end

  describe 'delegation' do
    context 'with hourly timeframe (P1H-P99H)' do
      it 'delegates to Influx::Total for P1H' do
        query =
          described_class.new(Timeframe.new('P1H')) { |q| q.sum :house_power }

        expect(query.executor).to be_a(Sensor::Query::Helpers::Influx::Total)
      end

      it 'delegates to Influx::Total for P24H' do
        query =
          described_class.new(Timeframe.new('P24H')) { |q| q.sum :house_power }

        expect(query.executor).to be_a(Sensor::Query::Helpers::Influx::Total)
      end

      it 'delegates to Influx::Total for P48H' do
        query =
          described_class.new(Timeframe.new('P48H')) { |q| q.sum :house_power }

        expect(query.executor).to be_a(Sensor::Query::Helpers::Influx::Total)
      end
    end

    context 'with non-hourly timeframes' do
      it 'delegates to Sql for Timeframe.day' do
        query = described_class.new(Timeframe.day) { |q| q.sum :house_power }

        expect(query.executor).to be_a(Sensor::Query::Helpers::Sql::Total)
      end

      it 'delegates to Sql for monthly timeframe' do
        query =
          described_class.new(Timeframe.new('2025-01')) do |q|
            q.sum :house_power
          end

        expect(query.executor).to be_a(Sensor::Query::Helpers::Sql::Total)
      end

      it 'delegates to Sql for yearly timeframe' do
        query =
          described_class.new(Timeframe.new('2025')) { |q| q.sum :house_power }

        expect(query.executor).to be_a(Sensor::Query::Helpers::Sql::Total)
      end
    end
  end

  describe '#call' do
    context 'with hourly timeframe' do
      subject(:query) do
        described_class.new(Timeframe.new('P24H')) do |q|
          q.sum :grid_import_power
        end
      end

      it 'returns data from Influx backend' do
        data = query.call

        expect(data).to be_a(Sensor::Data::Single)
        expect(data.grid_import_power).to be_a(Numeric).or be_nil
      end
    end

    context 'with daily timeframe' do
      subject(:query) do
        described_class.new(Timeframe.day) { |q| q.sum :grid_import_power }
      end

      it 'returns data from SQL backend' do
        data = query.call

        expect(data).to be_a(Sensor::Data::Single)
        expect(data.grid_import_power).to be_a(Numeric).or be_nil
      end
    end
  end

  describe '#timeframe' do
    it 'returns the timeframe from delegate' do
      tf = Timeframe.new('P24H')
      query = described_class.new(tf) { |q| q.sum :house_power }

      expect(query.timeframe).to eq(tf)
    end
  end
end
