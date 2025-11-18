describe Sensor::Query::Helpers::Influx::Total do
  describe 'initialization' do
    context 'without block' do
      it 'raises ArgumentError' do
        expect { described_class.new(Timeframe.new('P24H')) }.to raise_error(
          ArgumentError,
          'Block required for DSL configuration',
        )
      end
    end

    context 'with non-hourly timeframe' do
      it 'raises ArgumentError' do
        expect do
          described_class.new(Timeframe.day) { |q| q.sum :house_power }
        end.to raise_error(
          ArgumentError,
          'Timeframe must be an hourly timeframe (P1H-P99H)',
        )
      end
    end

    context 'with hourly timeframe' do
      it 'does not raise error' do
        expect do
          described_class.new(Timeframe.new('P24H')) { |q| q.sum :house_power }
        end.not_to raise_error
      end
    end

    context 'with invalid aggregation' do
      it 'raises ArgumentError for avg on sum-only sensor' do
        expect do
          described_class.new(Timeframe.new('P24H')) do |q|
            q.avg :house_power # house_power only supports sum and max
          end
        end.to raise_error(
          ArgumentError,
          /Sensor house_power doesn't support aggregation avg/,
        )
      end
    end
  end

  describe '#call' do
    subject(:call) { query.call }

    before do
      freeze_time

      # Setup test data - power readings over 25 hours
      influx_batch do
        (0..25).each do |hours_ago|
          add_influx_point(
            name: Sensor::Config.measurement(:inverter_power_1),
            fields: {
              Sensor::Config.field(:inverter_power_1) =>
                (hours_ago * 10) + 2000, # Varying power
              Sensor::Config.field(:house_power) => (hours_ago * 5) + 1500,
              Sensor::Config.field(:grid_import_power) => (hours_ago * 2) + 500,
            },
            time: hours_ago.hours.ago,
          )

          add_influx_point(
            name: Sensor::Config.measurement(:case_temp),
            fields: {
              Sensor::Config.field(:case_temp) => hours_ago + 20.0, # Temperature
            },
            time: hours_ago.hours.ago,
          )
        end
      end
    end

    context 'with single sum aggregation' do
      let(:query) do
        described_class.new(Timeframe.new('P24H')) { |q| q.sum :house_power }
      end

      it 'calculates energy integral (Wh)' do
        expect(call).to be_a(Sensor::Data::Single)
        expect(call.house_power).to be_a(Float)
        expect(call.house_power).to be > 0
      end
    end

    context 'with multiple sum aggregations' do
      let(:query) do
        described_class.new(Timeframe.new('P24H')) do |q|
          q.sum :house_power
          q.sum :grid_import_power
        end
      end

      it 'calculates integrals for all sensors' do
        expect(call).to be_a(Sensor::Data::Single)
        expect(call.house_power).to be_a(Float)
        expect(call.grid_import_power).to be_a(Float)
        expect(call.house_power).to be > 0
        expect(call.grid_import_power).to be > 0
      end
    end

    context 'with avg aggregation' do
      let(:query) do
        described_class.new(Timeframe.new('P24H')) { |q| q.avg :case_temp }
      end

      it 'calculates average value' do
        expect(call).to be_a(Sensor::Data::Single)
        expect(call.case_temp).to be_a(Float)
        expect(call.case_temp).to be_between(20, 50)
      end
    end

    context 'with mixed aggregations' do
      let(:query) do
        described_class.new(Timeframe.new('P24H')) do |q|
          q.sum :house_power
          q.sum :grid_import_power
          q.avg :case_temp
        end
      end

      it 'calculates all aggregations correctly' do
        expect(call).to be_a(Sensor::Data::Single)

        # Integrals for power sensors
        expect(call.house_power).to be_a(Float)
        expect(call.house_power).to be > 0
        expect(call.grid_import_power).to be_a(Float)
        expect(call.grid_import_power).to be > 0

        # Average for temperature
        expect(call.case_temp).to be_a(Float)
        expect(call.case_temp).to be_between(20, 50)
      end
    end

    context 'with explicit base_aggregation parameter' do
      let(:query) do
        described_class.new(Timeframe.new('P24H')) do |q|
          q.sum :house_power, :sum
          q.avg :case_temp, :avg
        end
      end

      it 'accepts and processes base_aggregation parameter' do
        expect(call).to be_a(Sensor::Data::Single)
        expect(call.house_power).to be_a(Float)
        expect(call.house_power).to be > 0
        expect(call.case_temp).to be_a(Float)
        expect(call.case_temp).to be_between(20, 50)
      end

      it 'groups queries by base_aggregation for efficiency' do
        # Verify that sensor_requests contain 3-tuple format
        expect(query.sensor_requests).to all(be_an(Array))
        expect(query.sensor_requests).to all(have_attributes(size: 3))

        # Check that base_aggregation is preserved
        house_power_request =
          query.sensor_requests.find { |req| req.first == :house_power }
        expect(house_power_request).to eq(%i[house_power sum sum])

        case_temp_request =
          query.sensor_requests.find { |req| req.first == :case_temp }
        expect(case_temp_request).to eq(%i[case_temp avg avg])
      end
    end

    context 'with calculated sensor' do
      let(:query) do
        described_class.new(Timeframe.new('P24H')) do |q|
          q.sum :grid_import_power
        end
      end

      before do
        # Create a price for finance calculations
        Price.create!(
          name: :electricity,
          value: 0.30,
          starts_at: 1.year.ago.to_date,
        )
      end

      it 'provides base data for finance calculations' do
        expect(call).to be_a(Sensor::Data::Single)
        expect(call.grid_import_power).to be_a(Float)
        expect(call.grid_import_power).to be > 0
      end
    end

    context 'with no data in timeframe' do
      let(:query) do
        described_class.new(Timeframe.new('P99H')) { |q| q.sum :house_power }
      end

      before do
        # Clear all data
        InfluxClient.delete_api.delete(
          Time.zone.at(0),
          Time.current,
          predicate:
            "_measurement=\"#{Sensor::Config.measurement(:inverter_power_1)}\"",
          bucket: Rails.configuration.x.influx.bucket,
          org: Rails.configuration.x.influx.org,
        )
      end

      it 'returns nil for sensors with no data' do
        expect(call).to be_a(Sensor::Data::Single)
        expect(call.house_power).to be_nil
      end
    end

    context 'with different hourly timeframes' do
      let(:query) do
        described_class.new(Timeframe.new(timeframe_string)) do |q|
          q.sum :house_power
        end
      end

      context 'with P1H' do
        let(:timeframe_string) { 'P1H' }

        it 'calculates for 1 hour' do
          expect(call.house_power).to be_a(Float)
          # P1H might have very small values close to 0
          expect(call.house_power).to be >= 0
        end
      end

      context 'with P48H' do
        let(:timeframe_string) { 'P48H' }

        it 'calculates for 48 hours' do
          expect(call.house_power).to be_a(Float)
          expect(call.house_power).to be > 0
        end
      end
    end
  end
end
