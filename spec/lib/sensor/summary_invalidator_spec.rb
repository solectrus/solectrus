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

    # The test configuration calculates inverter_power from
    # inverter_power_1 (my-pv:inverter_power) and inverter_power_2
    # (balcony:inverter_power).
    context 'with a summary of a past day' do
      let(:current_sensors) { current_config[:sensors_in_summary] }

      before do
        create_summary(
          date: Date.yesterday,
          values: [['inverter_power', 'sum', 1000]],
        )

        Setting.summary_config =
          current_config.merge(sensors_in_summary: stored_sensors)
      end

      context 'when an added sensor has data for that day' do
        let(:stored_sensors) { current_sensors.except(:inverter_power_2) }

        before do
          add_influx_point(
            name: 'balcony',
            fields: { inverter_power: 500 },
            time: Date.yesterday.middle_of_day,
          )
        end

        it 'deletes all summaries' do
          expect { validation }.to change(Summary, :count).from(2).to(0)
        end
      end

      context 'when an added sensor has data for today only' do
        let(:stored_sensors) { current_sensors.except(:inverter_power_2) }

        before do
          add_influx_point(
            name: 'balcony',
            fields: {
              inverter_power: 500,
            },
          )
        end

        it 'does not delete summaries' do
          expect { validation }.not_to change(Summary, :count)
        end
      end

      context 'when an added sensor has no data' do
        let(:stored_sensors) { current_sensors.except(:inverter_power_2) }

        it 'does not delete summaries' do
          expect { validation }.not_to change(Summary, :count)
        end
      end

      context 'when a removed inverter is part of that summary' do
        let(:stored_sensors) do
          current_sensors.merge(inverter_power_3: 'old-pv:inverter_power')
        end

        before do
          create_summary(
            date: Date.yesterday,
            values: [
              ['inverter_power', 'sum', 1000],
              ['inverter_power_3', 'sum', 500],
            ],
          )
        end

        it 'deletes all summaries' do
          expect { validation }.to change(Summary, :count).from(2).to(0)
        end
      end

      context 'when a removed inverter has zero in that summary' do
        let(:stored_sensors) do
          current_sensors.merge(inverter_power_3: 'old-pv:inverter_power')
        end

        before do
          create_summary(
            date: Date.yesterday,
            values: [
              ['inverter_power', 'sum', 1000],
              ['inverter_power_3', 'sum', 0],
            ],
          )
        end

        it 'does not delete summaries' do
          expect { validation }.not_to change(Summary, :count)
        end
      end

      context 'when a removed inverter is not part of that summary' do
        let(:stored_sensors) do
          current_sensors.merge(inverter_power_3: 'old-pv:inverter_power')
        end

        it 'does not delete summaries' do
          expect { validation }.not_to change(Summary, :count)
        end
      end

      context 'when a removed sensor other than an inverter is part of it' do
        let(:stored_sensors) { current_sensors }

        before do
          Sensor::Config.setup(
            ENV.to_hash.merge('INFLUX_SENSOR_WALLBOX_POWER' => ''),
          )

          create_summary(
            date: Date.yesterday,
            values: [
              ['inverter_power', 'sum', 1000],
              ['wallbox_power', 'sum', 500],
            ],
          )
        end

        after { Sensor::Config.setup(ENV) }

        it 'does not delete summaries' do
          expect { validation }.not_to change(Summary, :count)
        end
      end

      context 'when inverter_power was measured before' do
        let(:stored_sensors) do
          current_sensors.merge(inverter_power: 'my-pv:total_power')
        end

        it 'deletes all summaries' do
          expect { validation }.to change(Summary, :count).from(2).to(0)
        end
      end

      context 'when InfluxDB cannot be queried' do
        let(:stored_sensors) { current_sensors.except(:inverter_power_2) }

        before do
          allow(Influx).to receive(:query).and_raise(Influx::QueryError)
        end

        it 'deletes all summaries' do
          expect { validation }.to change(Summary, :count).from(2).to(0)
        end
      end

      # wallbox_car_connected has no daily value, but the detection reads it
      context 'when an added sensor of a step has data for that day' do
        let(:stored_sensors) { current_sensors.except(:wallbox_car_connected) }

        before do
          add_influx_point(
            name: Sensor::Config.measurement(:wallbox_car_connected),
            fields: { Sensor::Config.field(:wallbox_car_connected) => true },
            time: Date.yesterday.middle_of_day,
          )
        end

        it 'deletes all summaries' do
          expect { validation }.to change(Summary, :count).from(2).to(0)
        end
      end
    end

    # The test configuration has a wallbox and the state of charge of the
    # first car, so the detection and the proposals have something to do
    context 'with a summary of a past day and the steps' do
      let(:current_steps) { current_config[:steps] }

      before do
        create_summary(
          date: Date.yesterday,
          values: [['inverter_power', 'sum', 1000]],
        )

        Setting.summary_config = current_config.merge(steps: stored_steps)
      end

      context 'when a step has another version' do
        let(:stored_steps) { current_steps.merge('charging_sessions' => ChargingSession::Detection::VERSION - 1) }

        it 'deletes all summaries' do
          expect { validation }.to change(Summary, :count).from(2).to(0)
        end
      end

      context 'when a step has something to do now, with data of its sensors for that day' do
        let(:stored_steps) { current_steps.except('charging_sessions') }

        before do
          add_influx_point(
            name: Sensor::Config.measurement(:wallbox_power),
            fields: { Sensor::Config.field(:wallbox_power) => 5000 },
            time: Date.yesterday.middle_of_day,
          )
        end

        it 'deletes all summaries' do
          expect { validation }.to change(Summary, :count).from(2).to(0)
        end
      end

      context 'when a step has something to do now, without data of its sensors' do
        let(:stored_steps) { current_steps.except('charging_sessions') }

        it 'does not delete summaries' do
          expect { validation }.not_to change(Summary, :count)
        end
      end

      context 'when a step has nothing to do anymore' do
        let(:stored_steps) { current_steps.merge('place_visits' => Place::VisitDetection::VERSION) }

        it 'does not delete summaries' do
          expect { validation }.not_to change(Summary, :count)
        end
      end
    end
  end
end
