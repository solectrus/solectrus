describe Sensor::Query::Helpers::Sql::QueryBuilder do
  let(:timeframe) { Timeframe.new('2025-01-15') }

  describe '#initialize' do
    it 'initializes with required parameters' do
      sensor_requests = [
        %i[inverter_power_1 sum sum],
        %i[inverter_power_2 max sum],
      ]

      builder =
        described_class.new(
          sensor_requests: sensor_requests,
          timeframe:,
          group_by: :month,
        )

      expect(builder.sensor_requests).to eq(sensor_requests)
      expect(builder.timeframe).to eq(timeframe)
      expect(builder.group_by).to eq(:month)
    end

    it 'defaults group_by to nil' do
      builder =
        described_class.new(
          sensor_requests: [%i[inverter_power_1 sum sum]],
          timeframe:,
        )

      expect(builder.group_by).to be_nil
    end
  end

  describe '#call' do
    describe 'SQL structure generation' do
      it 'generates basic SQL structure with CTE' do
        builder =
          described_class.new(
            sensor_requests: [%i[inverter_power_1 sum sum]],
            timeframe:,
          )

        sql = builder.call

        expect(sql).to include('WITH daily AS (')
        expect(sql).to include('FROM summary_values sv')
        expect(sql).to include('GROUP BY sv.date')
        expect(sql).to include('FROM daily')
      end

      it 'includes correct date range filtering' do
        builder =
          described_class.new(
            sensor_requests: [%i[inverter_power_1 sum sum]],
            timeframe:,
          )

        sql = builder.call

        expect(sql).to include(
          "WHERE sv.date BETWEEN DATE '2025-01-15' AND DATE '2025-01-15'",
        )
      end

      it 'includes aggregation and field filtering' do
        builder =
          described_class.new(
            sensor_requests: [%i[inverter_power_1 sum sum]],
            timeframe:,
          )

        sql = builder.call

        expect(sql).to include("sv.aggregation IN ('sum')")
        expect(sql).to include("sv.field IN ('inverter_power_1')")
      end
    end

    context 'with single sensor' do
      it 'generates correct sensor columns' do
        builder =
          described_class.new(
            sensor_requests: [%i[inverter_power_1 max sum]],
            timeframe:,
          )

        sql = builder.call

        expect(sql).to include(
          "SUM(sv.value) FILTER (WHERE sv.aggregation = 'sum' AND sv.field = 'inverter_power_1') AS inverter_power_1_sum",
        )
        expect(sql).to include(
          'MAX(inverter_power_1_sum) AS inverter_power_1_max_sum',
        )
      end
    end

    context 'with multiple sensors' do
      it 'generates columns for all sensors' do
        builder =
          described_class.new(
            sensor_requests: [
              %i[inverter_power_1 sum sum],
              %i[inverter_power_2 max sum],
            ],
            timeframe:,
          )

        sql = builder.call

        expect(sql).to include('inverter_power_1_sum')
        expect(sql).to include('inverter_power_2_sum')
        expect(sql).to include(
          'SUM(inverter_power_1_sum) AS inverter_power_1_sum_sum',
        )
        expect(sql).to include(
          'MAX(inverter_power_2_sum) AS inverter_power_2_max_sum',
        )
      end

      it 'includes all required fields in filtering' do
        builder =
          described_class.new(
            sensor_requests: [
              %i[inverter_power_1 sum sum],
              %i[inverter_power_2 max sum],
            ],
            timeframe:,
          )

        sql = builder.call

        expect(sql).to include(
          "sv.field IN ('inverter_power_1','inverter_power_2')",
        )
      end
    end

    context 'with group_by parameter' do
      it 'generates correct grouping columns for month' do
        builder =
          described_class.new(
            sensor_requests: [%i[inverter_power_1 sum sum]],
            timeframe: Timeframe.new('2025'),
            group_by: :month,
          )

        sql = builder.call

        expect(sql).to include("date_trunc('month', date)::date AS month")
        expect(sql).to include('GROUP BY 1')
        expect(sql).to include('ORDER BY 1')
      end

      it 'generates correct grouping columns for day' do
        builder =
          described_class.new(
            sensor_requests: [%i[inverter_power_1 sum sum]],
            timeframe: Timeframe.new('2025-01'),
            group_by: :day,
          )

        sql = builder.call

        expect(sql).to include('date')
        expect(sql).to include('GROUP BY 1')
        expect(sql).to include('ORDER BY 1')
      end

      it 'generates correct grouping columns for week' do
        builder =
          described_class.new(
            sensor_requests: [%i[inverter_power_1 sum sum]],
            timeframe: Timeframe.new('2025-01'),
            group_by: :week,
          )

        sql = builder.call

        expect(sql).to include("date_trunc('week', date)::date AS week")
      end

      it 'generates correct grouping columns for year' do
        builder =
          described_class.new(
            sensor_requests: [%i[inverter_power_1 sum sum]],
            timeframe: Timeframe.new('2025'),
            group_by: :year,
          )

        sql = builder.call

        expect(sql).to include("date_trunc('year', date)::date AS year")
      end
    end

    context 'without group_by' do
      it 'omits grouping and ordering clauses' do
        builder =
          described_class.new(
            sensor_requests: [%i[inverter_power_1 sum sum]],
            timeframe: timeframe,
          )

        sql = builder.call

        expect(sql).not_to include('GROUP BY 1')
        expect(sql).not_to include('ORDER BY 1')
        expect(sql).not_to include('date_trunc')
      end
    end
  end

  describe 'price integration' do
    context 'when sensors require prices' do
      it 'does not include price CTE for standard sensors' do
        builder =
          described_class.new(
            sensor_requests: [%i[inverter_power_1 sum sum]],
            timeframe:,
          )

        sql = builder.call

        expect(sql).not_to include('WITH price_ranges')
        expect(sql).not_to include('JOIN price_ranges')
      end
    end
  end

  describe 'sensor registry integration' do
    it 'works with any sensor from registry' do
      # Use first available sensor from registry
      sensor_name = Sensor::Registry.all.reject(&:calculated?).first&.name

      builder =
        described_class.new(
          sensor_requests: [[sensor_name, :sum, :sum]],
          timeframe:,
        )

      sql = builder.call
      expect(sql).to include(sensor_name.to_s)
    end

    it 'generates sensor-agnostic SQL structure' do
      builder =
        described_class.new(
          sensor_requests: [%i[inverter_power_1 sum sum]],
          timeframe:,
        )

      sql = builder.call

      # Should not contain hardcoded sensor names in structure
      expect(sql).to include('sv.field')
      expect(sql).to include('sv.aggregation')
      expect(sql).to include('sv.value')
    end
  end
end
