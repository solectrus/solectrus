describe Sensor::Query::Latest do
  let(:available_sensors) do
    %i[inverter_power_1 inverter_power_2 house_power battery_soc]
  end
  let(:unconfigured_sensor) { :inverter_power_5 } # This one is empty in .env.test

  before do
    # Mock ApplicationPolicy to allow heatpump sensors
    stub_feature(:heatpump)

    influx_batch do
      add_influx_point(
        name: 'my-pv',
        fields: {
          inverter_power: 2500.0,
          house_power: 1800.0,
          bat_fuel_charge: 85.5,
        },
        time: 1.minute.ago,
      )

      add_influx_point(
        name: 'balcony',
        fields: {
          inverter_power: 500.0,
        },
        time: 2.minutes.ago,
      )
    end
  end

  describe '#initialize' do
    it 'accepts single sensor name as symbol' do
      query = described_class.new(:house_power)
      expect(query.sensor_names).to eq([:house_power])
    end

    it 'accepts multiple sensor names' do
      query = described_class.new(available_sensors)
      expect(query.sensor_names).to eq(available_sensors)
    end

    it 'uses Timeframe.now' do
      query = described_class.new(:house_power)
      expect(query.timeframe).to be_now
    end
  end

  describe '#call' do
    context 'with configured sensors' do
      it 'returns latest values from InfluxDB for single sensor' do
        result = described_class.new([:house_power]).call

        expect(result).to be_a(Sensor::Data::Base)
        expect(result.house_power).to eq(1800.0) # From test data
      end

      it 'returns latest values for multiple sensors from same measurement' do
        result = described_class.new(%i[house_power battery_soc]).call

        expect(result).to be_a(Sensor::Data::Base)
        expect(result.house_power).to eq(1800.0)
        expect(result.battery_soc).to eq(85.5) # bat_fuel_charge from test data
      end

      it 'returns latest values for sensors from different measurements' do
        result = described_class.new(%i[inverter_power_1 inverter_power_2]).call

        expect(result).to be_a(Sensor::Data::Base)
        expect(result.inverter_power_1).to eq(2500.0) # From my-pv measurement
        expect(result.inverter_power_2).to eq(500.0) # From balcony measurement
      end

      it 'handles single sensor correctly' do
        result = described_class.new(:house_power).call

        expect(result).to be_a(Sensor::Data::Base)
        expect(result.house_power).to eq(1800.0)
      end

      it 'correctly calculates house_power with dependency exclusion' do
        # This test specifically verifies that house_power dependencies are calculated
        # We expect house_power to be calculated as: base_house_power - heatpump_power
        # Since heatpump_power is excluded from house_power in .env.test

        # Add heatpump_power test data
        influx_batch do
          add_influx_point(
            name: 'Heatpump',
            fields: {
              power: 300.0,
            },
            time: 1.minute.ago,
          )
        end

        result = described_class.new(:house_power).call

        expect(result).to be_a(Sensor::Data::Base)
        # Expected: 1800.0 (base house_power) - 300.0 (heatpump_power) = 1500.0
        expect(result.house_power).to eq(1500.0)
      end
    end

    context 'with empty sensor list' do
      it 'raises ArgumentError for empty sensor array' do
        expect { described_class.new([]) }.to raise_error(
          ArgumentError,
          'Sensor names cannot be empty',
        )
      end
    end

    context 'with no data in InfluxDB' do
      it 'returns empty data when no recent data exists' do
        # Test with a sensor that has no recent data
        result = described_class.new([:system_status]).call
        expect(result).to be_a(Sensor::Data::Base)
        expect(result.raw_data).to eq({})
      end
    end

    context 'with stale data (older than MAX_AGE)' do
      before do
        influx_batch do
          add_influx_point(
            name: 'Heatpump',
            fields: {
              power: 800.0,
            },
            time: 30.minutes.ago,
          )
        end
      end

      it 'hides values older than 15 minutes' do
        result = described_class.new(:heatpump_power).call

        expect(result.heatpump_power).to be_nil
      end

      it 'keeps fresh values from a sibling sensor' do
        result = described_class.new(%i[heatpump_power house_power]).call

        # heatpump_power is 30 min old (stale), house_power is 1 min old
        expect(result.heatpump_power).to be_nil
        expect(result.house_power).to eq(1800.0)
      end
    end

    context 'with car_battery_soc_1, which is a state' do
      before do
        influx_batch do
          add_influx_point(
            name: 'Trabant',
            fields: {
              soc: 60.0,
            },
            time: 90.minutes.ago,
          )
        end
        stub_feature(:car)
      end

      it 'keeps an older value' do
        result = described_class.new(:car_battery_soc_1).call
        expect(result.car_battery_soc_1).to eq(60.0)
      end

      # A source like TeslaMate sends only a change, so a parked car is quiet
      it 'keeps a value older than the day that the query reads' do
        influx_batch { add_influx_point(name: 'Trabant', fields: { range: 210.0 }, time: 3.days.ago) }
        Sensor::Config.setup(ENV.to_h.merge('INFLUX_SENSOR_CAR_RANGE_1' => 'Trabant:range'))

        result = described_class.new(%i[car_battery_soc_1 car_range_1]).call

        expect(result.car_range_1).to eq(210.0)
        expect(result.time_for(:car_range_1)).to be_within(1.second).of(3.days.ago)
      ensure
        Sensor::Config.setup(ENV)
      end

      # The maximum range is calculated, so it never has a reading of its own.
      # The search of the history reads its inputs from before the day.
      it 'keeps the values of the day over older ones' do
        influx_batch do
          add_influx_point(name: 'Trabant', fields: { soc: 70.0, range: 210.0 }, time: 3.days.ago)
          add_influx_point(name: 'Trabant', fields: { range: 150.0 }, time: 90.minutes.ago)
        end
        Sensor::Config.setup(ENV.to_h.merge('INFLUX_SENSOR_CAR_RANGE_1' => 'Trabant:range'))

        result = described_class.new(%i[car_battery_soc_1 car_range_1 car_max_range_1]).call

        expect([result.car_battery_soc_1, result.car_range_1, result.car_max_range_1]).to eq([60.0, 150.0, 250.0])
      ensure
        Sensor::Config.setup(ENV)
      end

      # A configuration for tests can give two cars the same field
      context 'when a second car reads the same field' do
        before { Sensor::Config.setup(ENV.to_h.merge('INFLUX_SENSOR_CAR_BATTERY_SOC_2' => 'Trabant:soc')) }
        after { Sensor::Config.setup(ENV) }

        it 'gives the value to both cars' do
          result = described_class.new(%i[car_battery_soc_1 car_battery_soc_2]).call

          expect([result.car_battery_soc_1, result.car_battery_soc_2]).to eq([60.0, 60.0])
        end
      end
    end
  end
end
