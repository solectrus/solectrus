describe PowerChart do
  let(:measurement) { "Test#{described_class}" }

  let(:beginning) { 1.year.ago.beginning_of_year }

  before do
    influx_batch do
      12.times do |index|
        add_influx_point name: measurement,
                         fields: {
                           inverter_power: (index + 1) * 1000,
                           bat_power_plus: (index + 1) * 100,
                           bat_power_minus: (index + 1) * 200,
                         },
                         time: (beginning + index.month).end_of_month
        add_influx_point name: measurement,
                         fields: {
                           inverter_power: (index + 1) * 1000,
                           bat_power_plus: (index + 1) * 100,
                           bat_power_minus: (index + 1) * 200,
                         },
                         time: (beginning + index.month).beginning_of_month
      end

      add_influx_point name: measurement,
                       fields: {
                         inverter_power: 14_000,
                         bat_power_plus: 2000,
                         bat_power_minus: 100,
                       }
    end
  end

  around { |example| freeze_time(&example) }

  context 'when one field is requested' do
    let(:chart) do
      described_class.new(
        fields: ['inverter_power'],
        measurements: [measurement],
      )
    end

    describe '#call' do
      subject(:result) { chart.call(timeframe)['inverter_power'] }

      context 'when timeframe is "now"' do
        let(:timeframe) { Timeframe.now }

        it { is_expected.to have(1.hour / 20.seconds).items }

        it 'contains last data point' do
          last = result.last

          expect(last[1]).to eq(14.0)
          expect(last[0]).to be_within(20.seconds).of(Time.current)
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
        fields: %w[bat_power_plus bat_power_minus],
        measurements: [measurement],
      )
    end

    describe '#call' do
      subject(:call) { chart.call(timeframe) }

      context 'when timeframe is "now"' do
        let(:timeframe) { Timeframe.now }

        it 'returns key for each requested field' do
          expect(call.keys).to eq(%w[bat_power_minus bat_power_plus])
        end

        describe 'bat_power_plus' do
          subject(:result) { call['bat_power_plus'] }

          it { is_expected.to have(1.hour / 20.seconds).items }

          it 'contains last data point' do
            last = result.last

            expect(last[1]).to eq(2.0)
            expect(last[0]).to be_within(20.seconds).of(Time.current)
          end
        end
      end

      context 'when timeframe is a year' do
        let(:timeframe) { Timeframe.new(beginning.year.to_s) }

        it 'returns key for each requested field' do
          expect(call.keys).to eq(%w[bat_power_minus bat_power_plus])
        end

        describe 'bat_power_plus' do
          subject(:result) { call['bat_power_plus'] }

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
