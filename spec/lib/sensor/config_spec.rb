describe Sensor::Config do
  let(:instance) { described_class.instance }

  let(:env) do
    {
      'INFLUX_SENSOR_INVERTER_POWER' => 'pv:inverter_power',
      'INFLUX_SENSOR_HOUSE_POWER' => 'pv:house_power',
      'INFLUX_SENSOR_GRID_IMPORT_POWER' => 'pv:grid_import_power',
      'INFLUX_SENSOR_HEATPUMP_POWER' => 'heatpump:power',
      'INFLUX_EXCLUDE_FROM_HOUSE_POWER' => 'HEATPUMP_POWER',
    }
  end

  before { described_class.setup(env) }

  describe '.setup' do
    it 'configures the singleton instance' do
      expect { described_class.setup(env) }.not_to raise_error
    end

    context 'with logging' do
      it 'logs sensor initialization' do
        allow(Rails.logger).to receive(:info)
        allow(Rails.logger).to receive(:warn)

        described_class.setup(env)

        expect(Rails.logger).to have_received(:info).with(
          'Sensor initialization started',
        )
        expect(Rails.logger).to have_received(:info).with(
          'Sensor initialization completed',
        )
      end

      it 'logs configured sensors' do
        allow(Rails.logger).to receive(:info)
        allow(Rails.logger).to receive(:warn)

        described_class.setup(env)

        expect(Rails.logger).to have_received(:info).with(
          include('INVERTER_POWER', 'pv:inverter_power'),
        )
        expect(Rails.logger).to have_received(:info).with(
          include('HOUSE_POWER', 'pv:house_power'),
        )
      end

      it 'logs house power exclusions when configured' do
        allow(Rails.logger).to receive(:info)
        allow(Rails.logger).to receive(:warn)

        described_class.setup(env)

        expect(Rails.logger).to have_received(:info).with(
          include('HOUSE_POWER subtracts HEATPUMP_POWER'),
        )
      end

      context 'when no exclusions are configured' do
        let(:env_without_exclusions) do
          {
            'INFLUX_SENSOR_INVERTER_POWER' => 'pv:inverter_power',
            'INFLUX_SENSOR_HOUSE_POWER' => 'pv:house_power',
          }
        end

        it 'logs house power unchanged' do
          allow(Rails.logger).to receive(:info)
          allow(Rails.logger).to receive(:warn)

          described_class.setup(env_without_exclusions)

          expect(Rails.logger).to have_received(:info).with(
            '  - Sensor HOUSE_POWER remains unchanged',
          )
        end
      end

      context 'when duplicate configurations exist' do
        let(:env_with_duplicates) do
          {
            'INFLUX_SENSOR_INVERTER_POWER' => 'pv:inverter_power',
            'INFLUX_SENSOR_WALLBOX_POWER' => 'senec:wallbox_power',
            'INFLUX_SENSOR_HEATPUMP_POWER' => 'senec:wallbox_power', # duplicate!
          }
        end

        it 'warns about duplicate configurations' do
          allow(Rails.logger).to receive(:info)
          allow(Rails.logger).to receive(:warn)

          described_class.setup(env_with_duplicates)

          expect(Rails.logger).to have_received(:warn).with(
            %r{Duplicate measurement/field combinations detected},
          )
          expect(Rails.logger).to have_received(:warn).with(
            include(
              'WALLBOX_POWER',
              'HEATPUMP_POWER',
              'senec:wallbox_power',
            ),
          )
        end
      end
    end
  end

  describe '.exists?' do
    it 'returns true for configured sensors' do
      expect(described_class.exists?(:inverter_power)).to be(true)
      expect(described_class.exists?(:house_power)).to be(true)
    end

    it 'raises error for non-existent sensors' do
      expect { described_class.exists?(:non_existent_sensor) }.to raise_error(
        ArgumentError,
        'Unknown sensor: non_existent_sensor',
      )
    end

    it 'respects check_policy parameter' do
      expect(
        described_class.exists?(:inverter_power, check_policy: false),
      ).to be(true)
      expect(
        described_class.exists?(:inverter_power, check_policy: true),
      ).to be(true)
    end

    it 'returns true when check_policy is false even if sensor is not permitted' do
      allow(Sensor::Registry[:inverter_power]).to receive(
        :permitted?,
      ).and_return(false)

      expect(
        described_class.exists?(:inverter_power, check_policy: false),
      ).to be(true)
      expect(
        described_class.exists?(:inverter_power, check_policy: true),
      ).to be(false)
    end
  end

  describe '.measurement' do
    it 'returns correct measurement for configured sensors' do
      expect(described_class.measurement(:inverter_power)).to eq('pv')
      expect(described_class.measurement(:heatpump_power)).to eq('heatpump')
    end

    it 'returns nil for non-configured sensors' do
      expect(described_class.measurement(:non_existent_sensor)).to be_nil
    end
  end

  describe '#field' do
    it 'returns correct field for configured sensors' do
      expect(instance.field(:inverter_power)).to eq('inverter_power')
      expect(instance.field(:heatpump_power)).to eq('power')
    end

    it 'returns nil for non-configured sensors' do
      expect(instance.field(:non_existent_sensor)).to be_nil
    end
  end

  describe '#find_by' do
    it 'finds sensor by measurement and field' do
      expect(
        instance.find_by(measurement: 'pv', field: 'inverter_power'),
      ).to eq(:inverter_power)
      expect(instance.find_by(measurement: 'heatpump', field: 'power')).to eq(
        :heatpump_power,
      )
    end

    it 'returns nil when not found' do
      expect(
        instance.find_by(measurement: 'nonexistent', field: 'field'),
      ).to be_nil
    end
  end

  describe '#house_power_excluded_sensors' do
    it 'returns excluded sensor names' do
      expect(instance.house_power_excluded_sensors).to eq(
        [Sensor::Registry[:heatpump_power]],
      )
    end
  end

  context 'when INFLUX_EXCLUDE_FROM_HOUSE_POWER is empty' do
    let(:env) { { 'INFLUX_SENSOR_HOUSE_POWER' => 'pv:house_power' } }

    it 'returns empty array for excluded sensors' do
      expect(described_class.instance.house_power_excluded_sensors).to eq([])
    end
  end

  context 'when house_power is not configured' do
    let(:env) { { 'INFLUX_SENSOR_INVERTER_POWER' => 'pv:inverter_power' } }

    it 'returns empty array for excluded sensors' do
      expect(described_class.instance.house_power_excluded_sensors).to eq([])
    end
  end

  context 'when INFLUX_EXCLUDE_FROM_HOUSE_POWER contains unknown sensors' do
    let(:invalid_env) do
      {
        'INFLUX_SENSOR_HOUSE_POWER' => 'pv:house_power',
        'INFLUX_EXCLUDE_FROM_HOUSE_POWER' => 'HEATPUMP_POWER,UNKNOWN_SENSOR',
      }
    end

    it 'raises error for unknown sensors' do
      expect { described_class.setup(invalid_env) }.to raise_error(
        ArgumentError,
        'Unknown sensor: unknown_sensor',
      )
    end
  end

  describe 'sensor filtering methods' do
    describe '#nameable_sensors' do
      it 'returns sensors that are nameable' do
        sensors = instance.nameable_sensors
        expect(sensors).to be_an(Array)
        expect(sensors.all?(&:nameable?)).to be(true)
      end
    end

    describe '#chart_sensors' do
      it 'returns sensors that are chart enabled' do
        sensors = instance.chart_sensors
        expect(sensors).to be_an(Array)
        expect(sensors.all?(&:chart_enabled?)).to be(true)
      end
    end

    describe '#top10_sensors' do
      it 'returns sensors that are top10 enabled' do
        sensors = instance.top10_sensors
        expect(sensors).to be_an(Array)
        expect(sensors.all?(&:top10_enabled?)).to be(true)
      end
    end
  end

  context 'with PowerSplitter integration' do
    before do
      stub_feature(:power_splitter)
    end

    it 'automatically configures power_splitter sensors when base sensors are present' do
      env_with_base =
        env.merge('INFLUX_SENSOR_WALLBOX_POWER' => 'senec:wallbox_power')

      described_class.setup(env_with_base)

      # Base sensor should be configured
      expect(described_class.exists?(:wallbox_power)).to be true

      # PowerSplitter sensor should be auto-configured
      expect(described_class.exists?(:wallbox_power_grid)).to be true
      expect(
        described_class.measurement(:wallbox_power_grid),
      ).to eq 'power_splitter'
      expect(
        described_class.field(:wallbox_power_grid),
      ).to eq 'wallbox_power_grid'
    end

    it 'does not configure power_splitter sensors when base sensors are missing' do
      # Setup without wallbox_power
      described_class.setup(env)

      # PowerSplitter sensor should NOT be configured
      expect(described_class.exists?(:wallbox_power_grid)).to be false
    end
  end
end
