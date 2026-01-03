describe Sensor::Query::Helpers::Sql::DslBuilder do
  let(:builder) { described_class.new }

  describe '#initialize' do
    it 'initializes with empty sensor requests' do
      expect(builder.sensor_requests).to be_empty
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
        builder.min :outdoor_temp, :min
        expect(builder.sensor_requests).to include(%i[outdoor_temp min min])
      end

      it 'defaults to min base aggregation' do
        builder.min :outdoor_temp
        expect(builder.sensor_requests).to include(%i[outdoor_temp min min])
      end
    end

    describe '#max' do
      it 'adds max aggregation to sensor requests' do
        builder.max :outdoor_temp, :max
        expect(builder.sensor_requests).to include(%i[outdoor_temp max max])
      end

      it 'defaults to max base aggregation' do
        builder.max :outdoor_temp
        expect(builder.sensor_requests).to include(%i[outdoor_temp max max])
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

  describe '#group_by' do
    it 'sets group_by value' do
      builder.group_by :month
      expect(builder.group_by_value).to eq(:month)
    end
  end

  describe 'multiple aggregations' do
    it 'handles multiple sensors' do
      builder.sum :house_power, :sum
      builder.avg :outdoor_temp, :min
      builder.max :outdoor_temp, :max

      expect(builder.sensor_requests).to include(%i[house_power sum sum])
      expect(builder.sensor_requests).to include(%i[outdoor_temp avg min])
      expect(builder.sensor_requests).to include(%i[outdoor_temp max max])
    end
  end
end
