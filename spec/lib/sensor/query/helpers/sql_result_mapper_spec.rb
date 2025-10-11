describe Sensor::Query::Helpers::SqlResultMapper do
  let(:timeframe) { Timeframe.new('2025-01-15') }

  describe '#initialize' do
    it 'initializes with required parameters' do
      sensor_requests = [%i[inverter_power_1 sum sum]]

      mapper = described_class.new(sensor_requests, group_by: :month, timeframe:)

      expect(mapper.sensor_requests).to eq(sensor_requests)
      expect(mapper.group_by).to eq(:month)
      expect(mapper.timeframe).to eq(timeframe)
    end

    it 'defaults group_by to nil' do
      mapper = described_class.new([%i[inverter_power_1 sum sum]], timeframe:)

      expect(mapper.group_by).to be_nil
    end
  end

  describe '#call' do
    context 'with nil or empty data' do
      let(:mapper) do
        described_class.new(
          [%i[inverter_power_1 sum sum]],
          group_by: nil,
          timeframe:,
        )
      end

      it 'returns empty hash for nil' do
        expect(mapper.call(nil)).to eq({})
      end

      it 'maps empty hash with missing column to nil value' do
        result = mapper.call({})

        expect(result).to eq(%i[inverter_power_1 sum sum] => nil)
      end
    end

    context 'when processing single value queries without group_by' do
      let(:mapper) do
        described_class.new([%i[inverter_power_1 sum sum]], timeframe:)
      end

      it 'maps single hash result to sensor spec keys' do
        data = { 'inverter_power_1_sum_sum' => 100.5 }

        result = mapper.call(data)

        expect(result).to eq(%i[inverter_power_1 sum sum] => 100.5)
      end

      it 'maps single result with multiple sensors' do
        mapper =
          described_class.new(
            [%i[inverter_power_1 sum sum], %i[inverter_power_2 max sum]],
            group_by: nil,
            timeframe: timeframe,
          )
        data = {
          'inverter_power_1_sum_sum' => 100.5,
          'inverter_power_2_max_sum' => 200.0,
        }

        result = mapper.call(data)

        expect(result).to eq(
          %i[inverter_power_1 sum sum] => 100.5,
          %i[inverter_power_2 max sum] => 200.0,
        )
      end

      it 'handles missing columns as nil values' do
        data = {}

        result = mapper.call(data)

        expect(result).to eq(%i[inverter_power_1 sum sum] => nil)
      end
    end

    context 'when processing series queries with group_by' do
      let(:week_timeframe) { Timeframe.new('2025-W03') } # Week containing 2025-01-15 to 2025-01-21
      let(:mapper) do
        described_class.new(
          [%i[inverter_power_1 sum sum]],
          group_by: :day,
          timeframe: week_timeframe,
        )
      end

      it 'maps array of results with dates to series structure' do
        data = [
          {
            'date' => Date.parse('2025-01-15'),
            'inverter_power_1_sum_sum' => 100.0,
          },
          {
            'date' => Date.parse('2025-01-16'),
            'inverter_power_1_sum_sum' => 150.0,
          },
        ]

        result = mapper.call(data)

        expected_key = %i[inverter_power_1 sum sum]
        expect(result).to have_key(expected_key)
        expect(result[expected_key][Date.parse('2025-01-15')]).to eq(100.0)
        expect(result[expected_key][Date.parse('2025-01-16')]).to eq(150.0)
        # Period filling creates entries for the entire week
        expect(result[expected_key]).to have_key(Date.parse('2025-01-17'))
      end

      it 'maps array with multiple sensors' do
        mapper =
          described_class.new(
            [%i[inverter_power_1 sum sum], %i[inverter_power_2 max sum]],
            group_by: :day,
            timeframe: week_timeframe,
          )
        data = [
          {
            'date' => Date.parse('2025-01-15'),
            'inverter_power_1_sum_sum' => 100.0,
            'inverter_power_2_max_sum' => 200.0,
          },
        ]

        result = mapper.call(data)

        expected_key1 = %i[inverter_power_1 sum sum]
        expected_key2 = %i[inverter_power_2 max sum]

        expect(result).to have_key(expected_key1)
        expect(result).to have_key(expected_key2)
        expect(result[expected_key1][Date.parse('2025-01-15')]).to eq(100.0)
        expect(result[expected_key2][Date.parse('2025-01-15')]).to eq(200.0)
      end

      context 'with different group_by periods' do
        it 'handles month grouping' do
          month_timeframe = Timeframe.new('2025-01')
          mapper =
            described_class.new(
              [%i[inverter_power_1 sum sum]],
              group_by: :month,
              timeframe: month_timeframe,
            )
          data = [
            {
              'month' => Date.parse('2025-01-01'),
              'inverter_power_1_sum_sum' => 100.0,
            },
          ]

          result = mapper.call(data)

          expected_key = %i[inverter_power_1 sum sum]
          expect(result[expected_key]).to have_key(Date.parse('2025-01-01'))
          expect(result[expected_key][Date.parse('2025-01-01')]).to eq(100.0)
        end

        it 'handles year grouping' do
          year_timeframe = Timeframe.new('2024')
          mapper =
            described_class.new(
              [%i[inverter_power_1 sum sum]],
              group_by: :year,
              timeframe: year_timeframe,
            )
          data = [
            {
              'year' => Date.parse('2024-01-01'),
              'inverter_power_1_sum_sum' => 100.0,
            },
          ]

          result = mapper.call(data)

          expected_key = %i[inverter_power_1 sum sum]
          expect(result[expected_key]).to have_key(Date.parse('2024-01-01'))
          expect(result[expected_key][Date.parse('2024-01-01')]).to eq(100.0)
        end
      end

      it 'fills missing periods with nil values' do
        data = [
          {
            'date' => Date.parse('2025-01-15'),
            'inverter_power_1_sum_sum' => 100.0,
          },
        ]

        result = mapper.call(data)

        expected_key = %i[inverter_power_1 sum sum]
        # Other days in the week should be filled with nil
        expect(result[expected_key][Date.parse('2025-01-16')]).to be_nil
        expect(result[expected_key][Date.parse('2025-01-17')]).to be_nil
      end
    end

    context 'when validating data format' do
      it 'handles empty array for group_by queries with period filling' do
        mapper =
          described_class.new(
            [%i[inverter_power_1 sum sum]],
            group_by: :day,
            timeframe:,
          )

        result = mapper.call([])

        expected_key = %i[inverter_power_1 sum sum]
        # Empty data still gets period filling for the single day
        expect(result).to have_key(expected_key)
        expect(result[expected_key]).to have_key(Date.parse('2025-01-15'))
        expect(result[expected_key][Date.parse('2025-01-15')]).to be_nil
      end

      it 'raises validation error for array without group_by' do
        mapper =
          described_class.new(
            [%i[inverter_power_1 sum sum]],
            group_by: nil,
            timeframe:,
          )

        expect { mapper.call([{ 'data' => 'value' }]) }.to raise_error(
          ArgumentError,
          /Expected single row \(Hash\) for ungrouped query, got enumerable data/,
        )
      end

      it 'raises validation error for hash with group_by' do
        mapper =
          described_class.new(
            [%i[inverter_power_1 sum sum]],
            group_by: :day,
            timeframe:,
          )

        expect { mapper.call({ 'data' => 'value' }) }.to raise_error(
          ArgumentError,
          /Expected multiple rows \(enumerable\) for grouped query/,
        )
      end
    end

    context 'when extracting column names' do
      it 'extracts sensor names from column names correctly' do
        mapper =
          described_class.new(
            [%i[battery_charging_power max sum]],
            group_by: nil,
            timeframe:,
          )
        data = { 'battery_charging_power_max_sum' => 50.0 }

        result = mapper.call(data)

        expect(result).to eq(%i[battery_charging_power max sum] => 50.0)
      end

      it 'handles complex sensor names with underscores' do
        mapper =
          described_class.new(
            [%i[house_power_grid max sum]],
            group_by: nil,
            timeframe:,
          )
        data = { 'house_power_grid_max_sum' => 75.0 }

        result = mapper.call(data)

        expect(result).to eq(%i[house_power_grid max sum] => 75.0)
      end

      it 'ignores non-sensor columns' do
        mapper =
          described_class.new(
            [%i[inverter_power_1 sum sum]],
            group_by: nil,
            timeframe:,
          )
        data = {
          'inverter_power_1_sum_sum' => 100.0,
          'some_other_column' => 'ignored',
        }

        result = mapper.call(data)

        expect(result).to eq(%i[inverter_power_1 sum sum] => 100.0)
      end
    end
  end
end
