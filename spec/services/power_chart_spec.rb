describe PowerChart do
  let(:beginning) { 1.year.ago.beginning_of_year }

  def measurement
    Rails.application.config.x.influx.sensors.measurement(:inverter_power)
  end

  before do
    influx_batch do
      12.times do |index|
        add_influx_point name: measurement,
                         fields: {
                           field_inverter_power => (index + 1) * 1000,
                           field_battery_charging_power => (index + 1) * 100,
                           field_battery_discharging_power => (index + 1) * 200,
                         },
                         time: (beginning + index.month).end_of_month
        add_influx_point name: measurement,
                         fields: {
                           field_inverter_power => (index + 1) * 1000,
                           field_battery_charging_power => (index + 1) * 100,
                           field_battery_discharging_power => (index + 1) * 200,
                         },
                         time: (beginning + index.month).beginning_of_month
      end

      add_influx_point name: measurement,
                       fields: {
                         field_inverter_power => 14_000,
                         field_battery_charging_power => 2000,
                         field_battery_discharging_power => 100,
                       }
    end
  end

  around { |example| freeze_time(&example) }

  context 'when one sensor is requested' do
    let(:chart) { described_class.new(sensors: [:inverter_power]) }

    describe '#call' do
      subject(:result) { chart.call(timeframe)[:inverter_power] }

      context 'when timeframe is "now"' do
        let(:timeframe) { Timeframe.now }

        it { is_expected.to have(1.hour / 20.seconds).items }

        it 'contains last data point' do
          last = result.last

          expect(last[1]).to eq(14.0)
          expect(last.first).to be_within(20.seconds).of(Time.current)
        end
      end

      context 'when timeframe is a year' do
        let(:timeframe) { Timeframe.new(beginning.year.to_s) }

        it { is_expected.to have(12).items }

        it 'contains last and first data point' do
          expect(result.first).to eq([beginning, 1.0])
          expect(result.last).to eq(
            [beginning.end_of_year.beginning_of_month, 23.0],
          )
        end
      end
    end
  end

  context 'when two fields are requested' do
    let(:chart) do
      described_class.new(
        sensors: %w[battery_charging_power battery_discharging_power],
      )
    end

    describe '#call' do
      subject(:call) { chart.call(timeframe) }

      context 'when timeframe is "now"' do
        let(:timeframe) { Timeframe.now }

        it 'returns key for each requested sensor' do
          expect(call.keys).to eq(
            %i[battery_discharging_power battery_charging_power],
          )
        end

        describe 'battery_charging_power' do
          subject(:result) { call[:battery_charging_power] }

          it { is_expected.to have(1.hour / 20.seconds).items }

          it 'contains last data point' do
            last = result.last

            expect(last[1]).to eq(2.0)
            expect(last.first).to be_within(20.seconds).of(Time.current)
          end
        end
      end

      context 'when timeframe is a year' do
        let(:timeframe) { Timeframe.new(beginning.year.to_s) }

        it 'returns key for each requested sensor' do
          expect(call.keys).to eq(
            %i[battery_discharging_power battery_charging_power],
          )
        end

        describe 'battery_charging_power' do
          subject(:result) { call[:battery_charging_power] }

          it { is_expected.to have(12).items }

          it 'contains last and first data point' do
            expect(result.first).to eq([beginning, 0.1])
            expect(result.last).to eq(
              [beginning.end_of_year.beginning_of_month, 2.3],
            )
          end
        end
      end
    end
  end
end
