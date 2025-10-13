describe Sensor::Query::Sql do
  let(:timeframe) { Timeframe.new('2025-01-15') }

  describe '#initialize' do
    it 'requires a block for DSL configuration' do
      expect { described_class.new }.to raise_error(
        ArgumentError,
        /Block required for DSL configuration/,
      )
    end

    it 'builds sensor requests from DSL' do
      query =
        described_class.new do |q|
          q.sum :inverter_power_1, :sum
          q.avg :case_temp, :min
          q.timeframe timeframe
        end

      expect(query.sensor_requests).to include(%i[inverter_power_1 sum sum])
      expect(query.sensor_requests).to include(%i[case_temp avg min])
    end

    it 'sets timeframe from DSL' do
      query =
        described_class.new do |q|
          q.sum :inverter_power_1, :sum
          q.timeframe timeframe
        end

      expect(query.timeframe).to eq(timeframe)
    end

    it 'sets group_by from DSL' do
      query =
        described_class.new do |q|
          q.sum :inverter_power_1, :sum
          q.timeframe timeframe
          q.group_by :month
        end

      expect(query.group_by).to eq(:month)
    end

    it 'defaults group_by to nil' do
      query =
        described_class.new do |q|
          q.sum :inverter_power_1, :sum
          q.timeframe timeframe
        end

      expect(query.group_by).to be_nil
    end
  end

  describe 'DSL methods' do
    it 'supports sum aggregation' do
      query =
        described_class.new do |q|
          q.sum :house_power, :sum
          q.timeframe timeframe
        end

      expect(query.sensor_requests).to include(%i[house_power sum sum])
    end

    it 'supports avg aggregation' do
      query =
        described_class.new do |q|
          q.avg :case_temp, :avg
          q.timeframe timeframe
        end

      expect(query.sensor_requests).to include(%i[case_temp avg avg])
    end

    it 'supports min aggregation' do
      query =
        described_class.new do |q|
          q.min :case_temp, :min
          q.timeframe timeframe
        end

      expect(query.sensor_requests).to include(%i[case_temp min min])
    end

    it 'supports max aggregation' do
      query =
        described_class.new do |q|
          q.max :case_temp, :max
          q.timeframe timeframe
        end

      expect(query.sensor_requests).to include(%i[case_temp max max])
    end

    it 'supports different meta and base aggregations' do
      query =
        described_class.new do |q|
          q.avg :case_temp, :min
          q.timeframe timeframe
        end

      expect(query.sensor_requests).to include(%i[case_temp avg min])
    end

    it 'handles multiple sensors' do
      query =
        described_class.new do |q|
          q.sum :house_power, :sum
          q.avg :case_temp, :min
          q.max :case_temp, :max
          q.timeframe timeframe
        end

      expect(query.sensor_requests).to include(%i[house_power sum sum])
      expect(query.sensor_requests).to include(%i[case_temp avg min])
      expect(query.sensor_requests).to include(%i[case_temp max max])
    end

    it 'supports simplified syntax without base aggregation' do
      query =
        described_class.new do |q|
          q.sum :house_power
          q.timeframe timeframe
        end

      expect(query.sensor_requests).to include(%i[house_power sum sum])
    end
  end

  describe 'timeframe handling' do
    it 'accepts Timeframe objects' do
      query =
        described_class.new do |q|
          q.sum :house_power, :sum
          q.timeframe timeframe
        end

      expect(query.timeframe).to eq(timeframe)
    end

    it 'converts integers to Timeframe' do
      query =
        described_class.new do |q|
          q.sum :house_power, :sum
          q.timeframe 2025
        end

      expect(query.timeframe.to_s).to eq('2025')
    end

    it 'converts strings to Timeframe' do
      query =
        described_class.new do |q|
          q.sum :house_power, :sum
          q.timeframe '2025-01'
        end

      expect(query.timeframe.to_s).to eq('2025-01')
    end
  end

  describe '#call' do
    context 'without group_by' do
      it 'returns Sensor::Data::Single' do
        query =
          described_class.new do |q|
            q.sum :inverter_power_1, :sum
            q.timeframe timeframe
          end

        # Stub the fetch_raw_data method to avoid SQL execution
        allow(query).to receive(:fetch_raw_data).and_return({})

        result = query.call
        expect(result).to be_a(Sensor::Data::Single)
      end
    end

    context 'with group_by' do
      it 'returns Sensor::Data::Series' do
        query =
          described_class.new do |q|
            q.sum :inverter_power_1, :sum
            q.timeframe timeframe
            q.group_by :month
          end

        # Stub the fetch_raw_data method to avoid SQL execution
        allow(query).to receive(:fetch_raw_data).and_return({})

        result = query.call
        expect(result).to be_a(Sensor::Data::Series)
      end
    end
  end

  describe 'inheritance from base class' do
    it 'inherits sensor validation from base class' do
      query =
        described_class.new do |q|
          q.sum :inverter_power_1, :sum
          q.timeframe timeframe
        end

      # Sensor should be validated through base class mechanism
      expect(query.sensor_names).to include(:inverter_power_1)
    end

    it 'has access to timeframe from base class' do
      query =
        described_class.new do |q|
          q.sum :inverter_power_1, :sum
          q.timeframe timeframe
        end

      expect(query.timeframe).to eq(timeframe)
    end
  end

  describe 'sensor request processing' do
    it 'processes dependency resolution correctly' do
      query =
        described_class.new do |q|
          q.avg :autarky, :avg # Calculated sensor with dependencies
          q.timeframe timeframe
        end

      # Should include dependencies for calculated sensors
      expect(query.sensor_requests.length).to be > 1
      query.sensor_requests.each do |request|
        expect(request.length).to eq(3)
        expect(request.first).to be_a(Symbol)
        expect(request[1]).to be_a(Symbol)
        expect(request[2]).to be_a(Symbol)
      end
    end

    it 'handles calculated sensors correctly' do
      query =
        described_class.new do |q|
          q.sum :house_power, :sum # Calculated sensor
          q.timeframe timeframe
        end

      # Should process calculated sensors appropriately
      expect(query.sensor_requests).not_to be_empty
      expect(query.sensor_names).to include(:house_power)
    end

    context 'when querying calculated sensor with sql_calculation (savings)' do
      subject(:query) do
        described_class.new do |q|
          q.sum :savings, :sum
          q.timeframe timeframe
        end
      end

      let(:start_date) { Rails.configuration.x.installation_date }
      let(:end_date) { start_date + 1.month }
      let(:timeframe) { Timeframe.new("#{start_date}..#{end_date}") }
      let(:test_date) { start_date + 1.day }

      before do
        create_summary(
          date: test_date,
          values: [
            [:grid_import_power, :sum, 20_000],
            [:grid_export_power, :sum, 30_000],
            [:house_power, :sum, 30_000],
            [:heatpump_power, :sum, 10_000],
            [:wallbox_power, :sum, 5_000],
          ],
        )
      end

      it 'loads all required dependencies for Ruby calculation' do
        # Savings is a calculated sensor with sql_calculation method
        # It depends on traditional_costs and solar_price, which need Ruby calculation
        # So their dependencies must be loaded from SQL

        sensor_names = query.sensor_requests.map(&:first)

        # traditional_costs (FinanceBase) needs these base power sensors
        expect(sensor_names).to include(:house_power)
        expect(sensor_names).to include(:heatpump_power)
        expect(sensor_names).to include(:wallbox_power)

        # solar_price (calculated with sql_calculation) needs grid power
        expect(sensor_names).to include(:grid_import_power)
        expect(sensor_names).to include(:grid_export_power)

        # This test ensures that calculated sensors with sql_calculation
        # still load their dependencies when those dependencies need Ruby execution
      end

      it 'calculates the correct savings value' do
        result = query.call

        # With test data (all values in Wh):
        # house=30k, heatpump=10k, wallbox=5k, grid_import=20k, grid_export=30k
        # Prices: electricity=0.2545 EUR/kWh, feed_in=0.0832 EUR/kWh

        # traditional_costs = (30 + 10 + 5) * 0.2545 = 11.4525
        expect(result.traditional_costs).to be_within(0.0001).of(11.4525)

        # solar_price = 20*0.2545 - 30*0.0832 = 5.09 - 2.496 = 2.594
        expect(result.solar_price).to be_within(0.0001).of(2.594)

        # savings = 11.4525 - 2.594 = 8.8585
        expect(result.savings).to be_within(0.0001).of(8.8585)
      end
    end
  end
end
