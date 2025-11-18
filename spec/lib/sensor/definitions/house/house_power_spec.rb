Sensor::Registry[:house_power]

describe Sensor::Definitions::HousePower do # rubocop:disable RSpec/SpecFilePathFormat
  subject(:sensor) { described_class.new }

  describe '#calculate' do
    let(:timeframe) { Timeframe.now }

    context 'when exclusions are configured' do
      before { configure_exclusions([:heatpump_power]) }

      it 'is calculated' do
        expect(sensor).to be_calculated
      end

      context 'with valid input data' do
        let(:raw_data) { { house_power: 2000, heatpump_power: 300 } }

        it 'subtracts excluded sensor values from house power' do
          result = sensor.calculate(**raw_data)
          expect(result).to eq(2000 - 300)
        end
      end

      context 'when calculation would result in negative value' do
        let(:raw_data) { { house_power: 500, heatpump_power: 800 } }

        it 'returns zero as minimum value' do
          result = sensor.calculate(**raw_data)
          expect(result).to eq(0)
        end
      end

      context 'when house_power is missing' do
        let(:raw_data) { { house_power: nil, heatpump_power: 500 } }

        it 'returns nil when base value is unavailable' do
          result = sensor.calculate(**raw_data)
          expect(result).to be_nil
        end
      end
    end

    context 'when no exclusions are configured' do
      before { configure_exclusions([]) }

      it 'is not calculated' do
        expect(sensor).not_to be_calculated
      end

      context 'with any input data' do
        let(:raw_data) { { house_power: 2000, heatpump_power: 300 } }

        it 'returns the original house_power value unchanged' do
          result = sensor.calculate(**raw_data)
          expect(result).to eq(2000)
        end
      end
    end

    private

    def configure_exclusions(excluded_sensor_names)
      # Mock to return sensor objects, not just names
      excluded_sensors =
        excluded_sensor_names.map do |sensor_name|
          double('Sensor', name: sensor_name)
        end
      allow(Sensor::Config.instance).to receive(
        :house_power_excluded_sensors,
      ).and_return(excluded_sensors)
    end
  end

  describe 'Query::Sql' do
    subject(:sql_query) do
      case aggregation_option
      when Symbol
        Sensor::Query::Total.new(timeframe) do |q|
          q.public_send(aggregation_option, :house_power, aggregation_option)
        end
      when Array
        if aggregation_option.length == 2
          meta_agg = aggregation_option.first
          base_agg = aggregation_option[1]
          Sensor::Query::Total.new(timeframe) do |q|
            q.public_send(meta_agg, :house_power, base_agg)
          end
        else
          Sensor::Query::Total.new(timeframe) { |q| q.sum :house_power, :sum }
        end
      end
    end

    before do
      stub_feature(:heatpump)
      # Configure house_power as non-calculated (no exclusions)
      allow(Sensor::Config.instance).to receive(
        :house_power_excluded_sensors,
      ).and_return([])

      create_summary(
        date: '2024-01-15',
        values: [[:house_power, :sum, 10_000], [:heatpump_power, :sum, 15_000]],
      )

      create_summary(
        date: '2024-01-16',
        values: [[:house_power, :sum, 11_000], [:heatpump_power, :sum, 14_000]],
      )
    end

    let(:query_result) { sql_query.call }

    describe 'for a day' do
      let(:timeframe) { Timeframe.new('2024-01-15') }

      context 'when sum' do
        let(:aggregation_option) { :sum }

        it 'returns single value for this day' do
          expect(query_result.house_power(:sum, :sum)).to eq(10_000)
        end
      end

      context 'when max of sums for a day' do
        let(:aggregation_option) { %i[max sum] }

        it 'returns single value for this day' do
          expect(query_result.house_power(:max, :sum)).to eq(10_000)
        end
      end
    end

    describe 'for a month' do
      let(:timeframe) { Timeframe.new('2024-01') }

      context 'when sum' do
        let(:aggregation_option) { :sum }

        it 'returns single total for the month' do
          # For month timeframe without group_by, we get a single aggregated value
          expect(query_result.house_power(:sum, :sum)).to eq(21_000)
        end
      end

      context 'when sum of sums' do
        let(:aggregation_option) { %i[sum sum] }

        it 'returns single total' do
          expect(query_result.house_power(:sum, :sum)).to eq(21_000)
        end
      end

      context 'when unsupported meta-aggregations' do
        let(:aggregation_option) { %i[avg sum] }

        it 'raises an error during query construction' do
          expect { sql_query }.to raise_error(ArgumentError)
        end
      end

      context 'when unsupported base aggregations' do
        let(:aggregation_option) { :avg }

        it 'raises an error during query construction' do
          expect { sql_query }.to raise_error(ArgumentError)
        end
      end
    end
  end
end
