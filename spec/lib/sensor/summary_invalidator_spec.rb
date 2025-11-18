describe Sensor::SummaryInvalidator do
  before do
    create_summary(
      date: Date.current,
      values: [['inverter_power', 'sum', 1000]],
    )
  end

  # Use the actual current config from the system
  let(:current_config) { described_class.__send__(:build_config) }

  describe '.ensure_valid!' do
    subject(:validation) { described_class.ensure_valid! }

    context 'when stored config matches the current config' do
      before { Setting.summary_config = current_config }

      it 'does not delete summaries' do
        expect { validation }.not_to change(Summary, :count)
      end

      it 'does not update the stored config' do
        expect { validation }.not_to change(Setting, :summary_config)
      end
    end

    context 'when stored config has string keys but matches current config' do
      before do
        # Simulate what happens when a hash is stored as JSON and retrieved:
        # Symbol keys are converted to string keys
        string_key_config = JSON.parse(current_config.to_json)
        Setting.summary_config = string_key_config
      end

      it 'does not delete summaries' do
        expect { validation }.not_to change(Summary, :count)
      end

      it 'does not update the stored config' do
        expect { validation }.not_to change(Setting, :summary_config)
      end
    end

    context 'when stored config differs from the current config' do
      before { Setting.summary_config = { time_zone: 'Australia/Sydney' } }

      it 'deletes all summaries' do
        expect { validation }.to change(Summary, :count).from(1).to(
          0,
        ).and change(SummaryValue, :count).from(1).to(0)
      end

      it 'updates the stored config' do
        expect { validation }.to change(Setting, :summary_config)
      end
    end

    context 'when no stored config exists' do
      before { Setting.summary_config = nil }

      it 'deletes all summaries' do
        expect { validation }.to change(Summary, :count).from(1).to(
          0,
        ).and change(SummaryValue, :count).from(1).to(0)
      end

      it 'updates the stored config' do
        expect { validation }.to change(Setting, :summary_config)
      end
    end

    context 'when a sensor is added to the configuration' do
      before do
        Setting.summary_config = current_config

        Sensor::Config.setup(
          ENV.to_hash.merge(
            'INFLUX_SENSOR_INVERTER_POWER_5' => 'my-pv:mpp5_power',
          ),
        )
      end

      after { Sensor::Config.setup(ENV) }

      it 'does not delete summaries' do
        expect { validation }.not_to change(Summary, :count)
      end

      it 'updates the stored config to include new sensor' do
        expect { validation }.to change(Setting, :summary_config)
      end
    end
  end
end
