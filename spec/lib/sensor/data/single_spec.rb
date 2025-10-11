describe Sensor::Data::Single do
  subject(:data) { described_class.new(raw_data, timeframe:) }

  let(:timeframe) { Timeframe.day }

  describe 'initialization' do
    context 'with valid data' do
      it 'accepts Hash' do
        expect { described_class.new({}, timeframe:) }.not_to raise_error
      end

      it 'accepts symbol keys for current values' do
        expect do
          described_class.new({ house_power: 500 }, timeframe:)
        end.not_to raise_error
      end

      it 'accepts 2-element array keys' do
        expect do
          described_class.new({ %i[house_power sum] => 1000 }, timeframe:)
        end.not_to raise_error
      end

      it 'accepts 3-element array keys' do
        expect do
          described_class.new({ %i[house_power avg sum] => 1000 }, timeframe:)
        end.not_to raise_error
      end
    end

    context 'with invalid data' do
      it 'rejects Array' do
        expect { described_class.new([], timeframe:) }.to raise_error(
          ArgumentError,
          'Single data must be a Hash',
        )
      end

      it 'rejects String' do
        expect { described_class.new('invalid', timeframe:) }.to raise_error(
          ArgumentError,
          'Single data must be a Hash',
        )
      end

      it 'rejects invalid array key lengths' do
        expect do
          described_class.new({ [:house_power] => 1000 }, timeframe:)
        end.to raise_error(
          ArgumentError,
          /Array key must have 2 or 3 elements, got 1/,
        )

        expect do
          described_class.new(
            { %i[house_power sum avg extra] => 1000 },
            timeframe:,
          )
        end.to raise_error(
          ArgumentError,
          /Array key must have 2 or 3 elements, got 4/,
        )
      end

      it 'rejects non-symbol sensor names' do
        expect do
          described_class.new({ ['house_power', :sum] => 1000 }, timeframe:)
        end.to raise_error(ArgumentError, /Sensor name must be a Symbol/)
      end

      it 'rejects invalid aggregation types' do
        expect do
          described_class.new({ %i[house_power invalid] => 1000 }, timeframe:)
        end.to raise_error(ArgumentError, /Invalid aggregation: :invalid/)
      end

      it 'rejects invalid key formats' do
        expect do
          described_class.new({ 123 => 1000 }, timeframe:)
        end.to raise_error(ArgumentError, /Invalid key format: 123/)
      end
    end
  end

  describe 'use case: latest values' do
    let(:raw_data) do
      { house_power: 500, inverter_power: 300, case_temp: 32.5 }
    end

    it 'returns current values' do
      expect(data.house_power).to eq(500.0)
      expect(data.inverter_power).to eq(300.0)
      expect(data.case_temp).to eq(32.5)
    end

    it 'extracts sensor names correctly' do
      expect(data.sensor_names).to contain_exactly(
        :house_power,
        :inverter_power,
        :case_temp,
      )
    end

    it 'is a single data type' do
      expect(data.single?).to be true
      expect(data.series?).to be false
    end
  end

  describe 'use case: daily values with aggregation' do
    let(:raw_data) do
      {
        %i[house_power sum] => 10_500,
        %i[case_temp avg] => 33.4,
        %i[case_temp min] => 20,
        %i[grid_costs sum] => 1.3,
      }
    end

    describe 'method access' do
      it 'supports single param' do
        expect(data.house_power(:sum)).to eq(10_500)
        expect(data.case_temp(:avg)).to eq(33.4)
        expect(data.case_temp(:min)).to eq(20.0)
        expect(data.grid_costs(:sum)).to eq(1.3)
      end

      it 'supports missing param for sum' do
        expect(data.house_power).to eq(10_500)
        expect(data.grid_costs).to eq(1.3)
      end

      it 'rejects missing param for non-sum aggregations' do
        expect { data.case_temp }.to raise_error(ArgumentError)
      end

      it 'rejects invalid sensor' do
        expect { data.grid_import_power }.to raise_error(NoMethodError)
      end

      it 'raises exception for non-existent aggregation keys' do
        expect { data.house_power(:avg) }.to raise_error(
          ArgumentError,
          /No data found for sensor 'house_power' with aggregation 'avg'/,
        )
        expect { data.house_power(:max) }.to raise_error(
          ArgumentError,
          /No data found for sensor 'house_power' with aggregation 'max'/,
        )
      end

      it 'returns nil when key exists with nil value' do
        raw_data_with_nil = {
          %i[house_power sum] => 10_500,
          %i[case_temp avg] => nil, # Key exists but value is nil
          %i[case_temp min] => 20,
        }
        data_with_nil = described_class.new(raw_data_with_nil, timeframe:)

        expect(data_with_nil.case_temp(:avg)).to be_nil
        expect(data_with_nil.case_temp(:min)).to eq(20.0)
        expect(data_with_nil.house_power(:sum)).to eq(10_500.0)
      end
    end

    it 'extracts unique sensor names correctly' do
      expect(data.sensor_names).to contain_exactly(
        :house_power,
        :case_temp,
        :grid_costs,
      )
    end

    it 'returns smart sensor values that support both direct access and method calls' do
      # Should behave like numeric values when :sum aggregation is available
      expect(data.house_power).to eq(10_500)
      expect(data.grid_costs).to eq(1.3)

      # Should require explicit aggregation for sensors without :sum
      expect { data.case_temp }.to raise_error(
        ArgumentError,
        /has multiple aggregations. Use explicit aggregation parameters/,
      )
      # Should still support explicit method calls
      expect(data.house_power(:sum)).to eq(10_500)
      expect(data.case_temp(:avg)).to eq(33.4)
      expect(data.case_temp(:min)).to eq(20.0)
      expect(data.grid_costs(:sum)).to eq(1.3)
    end
  end

  describe 'use case: aggregation over time periods' do
    let(:raw_data) do
      {
        %i[case_temp avg min] => 18.5,
        %i[case_temp avg max] => 42.3,
        %i[traditional_costs sum sum] => 2345.67,
        %i[grid_revenue sum sum] => 1234.89,
      }
    end

    it 'supports method-based access with multiple parameters' do
      expect(data.case_temp(:avg, :min)).to eq(18.5)
      expect(data.case_temp(:avg, :max)).to eq(42.3)
      expect(data.traditional_costs(:sum, :sum)).to eq(2345.67)
      expect(data.grid_revenue(:sum, :sum)).to eq(1234.89)
    end

    it 'raises exception for non-existent multi-key combinations' do
      expect { data.case_temp(:min, :max) }.to raise_error(
        ArgumentError,
        /No data found for sensor 'case_temp' with meta-aggregation 'min' and aggregation 'max'/,
      )
      expect { data.traditional_costs(:avg, :sum) }.to raise_error(
        ArgumentError,
        /No data found for sensor 'traditional_costs' with meta-aggregation 'avg' and aggregation 'sum'/,
      )
    end

    it 'returns nil when meta-aggregation key exists with nil value' do
      raw_data_with_nil = {
        %i[case_temp avg min] => 18.5,
        %i[case_temp avg max] => nil, # Key exists but value is nil
        %i[traditional_costs sum sum] => 2345.67,
      }
      data_with_nil = described_class.new(raw_data_with_nil, timeframe:)

      expect(data_with_nil.case_temp(:avg, :min)).to eq(18.5)
      expect(data_with_nil.case_temp(:avg, :max)).to be_nil
      expect(data_with_nil.traditional_costs(:sum, :sum)).to eq(2345.67)
    end

    it 'extracts unique sensor names correctly' do
      expect(data.sensor_names).to contain_exactly(
        :case_temp,
        :traditional_costs,
        :grid_revenue,
      )
    end
  end

  describe 'use case: edge cases' do
    let(:raw_data) { {} }

    it 'handles empty data' do
      expect(data.sensor_names).to eq([])
    end

    it 'fails for non-existent sensors' do
      expect { data.non_existent_sensor }.to raise_error(NoMethodError)
    end
  end
end
