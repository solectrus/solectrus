describe PowerChart do
  let(:beginning) { 1.year.ago.beginning_of_year }

  def measurement
    SensorConfig.x.measurement(:inverter_power)
  end

  before do
    12.times do |index|
      Summary.create! date: beginning + index.months, # only one day per month
                      sum_inverter_power: (index + 1) * 1000 * 24, # 1 KW for 24 hours
                      sum_battery_charging_power: (index + 1) * 100 * 24, # 100 W for 24 hours
                      sum_battery_discharging_power: (index + 1) * 200 * 24 # 200 W for 24 hours
    end

    add_influx_point name: measurement,
                     fields: {
                       field_inverter_power => 14_000,
                       field_battery_charging_power => 2000,
                       field_battery_discharging_power => 100,
                     }
  end

  around { |example| freeze_time(&example) }

  context 'when one sensor is requested' do
    let(:chart) { described_class.new(sensors: [:inverter_power]) }

    describe '#call' do
      subject(:result) { chart.call(timeframe)[:inverter_power] }

      context 'when timeframe is "now"' do
        let(:timeframe) { Timeframe.now }

        it { is_expected.to have(1.hour / 30.seconds).items }

        it 'contains last data point' do
          last = result.last

          expect(last[1]).to eq(14_000)
          expect(last.first).to be_within(30.seconds).of(Time.current)
        end
      end

      context 'when timeframe is a year' do
        let(:timeframe) { Timeframe.new(beginning.year.to_s) }

        it { is_expected.to have(12).items }

        it 'contains last and first data point' do
          expect(result.first).to eq([beginning, 24_000])
          expect(result.last).to eq(
            [beginning.end_of_year.beginning_of_month, 288_000],
          )
        end
      end
    end
  end

  context 'when two fields are requested' do
    let(:chart) do
      described_class.new(
        sensors: %i[battery_charging_power battery_discharging_power],
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

          it { is_expected.to have(1.hour / 30.seconds).items }

          it 'contains last data point' do
            last = result.last

            expect(last[1]).to eq(2000)
            expect(last.first).to be_within(30.seconds).of(Time.current)
          end
        end
      end

      context 'when timeframe is a year' do
        let(:timeframe) { Timeframe.new(beginning.year.to_s) }

        it 'returns key for each requested sensor' do
          expect(call.keys).to eq(
            %i[battery_charging_power battery_discharging_power],
          )
        end

        describe 'battery_charging_power' do
          subject(:result) { call[:battery_charging_power] }

          it { is_expected.to have(12).items }

          it 'contains last and first data point' do
            expect(result.first).to eq([beginning, 2400])
            expect(result.last).to eq(
              [beginning.end_of_year.beginning_of_month, 28_800],
            )
          end
        end
      end
    end
  end
end
