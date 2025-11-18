describe Sensor::Query::Helpers::Sql::SelectBuilder do
  describe '#initialize' do
    it 'initializes with required parameters' do
      sensor_requests = [%i[inverter_power sum sum]]

      builder =
        described_class.new(sensor_requests: sensor_requests, group_by: :month)

      expect(builder.sensor_requests).to eq(sensor_requests)
      expect(builder.group_by).to eq(:month)
    end
  end

  describe '#build_final_select' do
    context 'without group_by' do
      it 'generates basic SELECT structure' do
        sensor_requests = [%i[inverter_power_1 sum sum]]

        builder = described_class.new(sensor_requests: sensor_requests)

        result = builder.build_final_select

        expect(result).to include('SELECT')
        expect(result).to include('FROM daily')
        expect(result).to include('inverter_power_1_sum_sum')
        expect(result).not_to include('GROUP BY')
        expect(result).not_to include('ORDER BY')
      end
    end

    context 'with group_by' do
      it 'generates SELECT with grouping for month' do
        sensor_requests = [%i[inverter_power_1 sum sum]]

        builder =
          described_class.new(
            sensor_requests: sensor_requests,
            group_by: :month,
          )

        result = builder.build_final_select

        expect(result).to include('SELECT')
        expect(result).to include('FROM daily')
        expect(result).to include('GROUP BY 1')
        expect(result).to include('ORDER BY 1')
        expect(result).to include("date_trunc('month', date)::date AS month")
      end

      it 'generates SELECT with grouping for day' do
        sensor_requests = [%i[inverter_power_1 sum sum]]

        builder =
          described_class.new(sensor_requests: sensor_requests, group_by: :day)

        result = builder.build_final_select

        expect(result).to include('date')
        expect(result).not_to include('date_trunc')
      end
    end

    context 'with multiple sensors' do
      it 'generates columns for all sensors' do
        sensor_requests = [
          %i[inverter_power_1 sum sum],
          %i[inverter_power_2 avg sum],
        ]

        builder = described_class.new(sensor_requests: sensor_requests)

        result = builder.build_final_select

        expect(result).to include('inverter_power_1_sum_sum')
        expect(result).to include('inverter_power_2_avg_sum')
      end
    end
  end
end
