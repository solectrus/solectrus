describe Sensor::Query::Helpers::SqlDslBuilder do
  let(:builder) { described_class.new }

  describe '#initialize' do
    it 'initializes with empty sensor requests' do
      expect(builder.sensor_requests).to be_empty
    end

    it 'initializes with nil timeframe' do
      expect(builder.timeframe_value).to be_nil
    end

    it 'initializes with nil group_by' do
      expect(builder.group_by_value).to be_nil
    end
  end

  describe 'DSL methods' do
    describe '#sum' do
      it 'adds sum aggregation to sensor requests' do
        builder.sum :house_power, :sum
        expect(builder.sensor_requests).to include(%i[house_power sum sum])
      end

      it 'defaults to sum base aggregation' do
        builder.sum :house_power
        expect(builder.sensor_requests).to include(%i[house_power sum sum])
      end
    end

    describe '#avg' do
      it 'adds avg aggregation to sensor requests' do
        builder.avg :case_temp, :min
        expect(builder.sensor_requests).to include(%i[case_temp avg min])
      end

      it 'defaults to avg base aggregation' do
        builder.avg :case_temp
        expect(builder.sensor_requests).to include(%i[case_temp avg avg])
      end
    end

    describe '#min' do
      it 'adds min aggregation to sensor requests' do
        builder.min :case_temp, :min
        expect(builder.sensor_requests).to include(%i[case_temp min min])
      end

      it 'defaults to min base aggregation' do
        builder.min :case_temp
        expect(builder.sensor_requests).to include(%i[case_temp min min])
      end
    end

    describe '#max' do
      it 'adds max aggregation to sensor requests' do
        builder.max :case_temp, :max
        expect(builder.sensor_requests).to include(%i[case_temp max max])
      end

      it 'defaults to max base aggregation' do
        builder.max :case_temp
        expect(builder.sensor_requests).to include(%i[case_temp max max])
      end
    end
  end

  describe 'validation' do
    it 'raises error for unknown sensor' do
      expect { builder.sum :unknown_sensor, :sum }.to raise_error(
        ArgumentError,
        /Unknown sensor/,
      )
    end

    it 'raises error for unsupported meta aggregation' do
      expect do
        builder.max :inverter_power_difference, :sum # inverter_power_difference only supports :sum
      end.to raise_error(ArgumentError, /doesn't support meta aggregation max/)
    end

    it 'allows valid aggregations' do
      expect { builder.sum :house_power, :sum }.not_to raise_error
    end
  end

  describe '#timeframe' do
    it 'accepts Timeframe objects' do
      timeframe = Timeframe.new('2025-01-15')
      builder.timeframe timeframe
      expect(builder.timeframe_value).to eq(timeframe)
    end

    it 'converts integers to Timeframe' do
      builder.timeframe 2025
      expect(builder.timeframe_value.to_s).to eq('2025')
    end

    it 'converts strings to Timeframe' do
      builder.timeframe '2025-01'
      expect(builder.timeframe_value.to_s).to eq('2025-01')
    end
  end

  describe '#group_by' do
    it 'sets group_by value' do
      builder.group_by :month
      expect(builder.group_by_value).to eq(:month)
    end
  end

  describe 'multiple aggregations' do
    it 'handles multiple sensors' do
      builder.sum :house_power, :sum
      builder.avg :case_temp, :min
      builder.max :case_temp, :max

      expect(builder.sensor_requests).to include(%i[house_power sum sum])
      expect(builder.sensor_requests).to include(%i[case_temp avg min])
      expect(builder.sensor_requests).to include(%i[case_temp max max])
    end
  end
end
