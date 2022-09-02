describe PowerChart do
  let(:measurement) { "Test#{described_class}" }

  let(:beginning) { 1.year.ago.beginning_of_year }

  before do
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

  around { |example| freeze_time(&example) }

  context 'when one field is requested' do
    let(:chart) do
      described_class.new(
        fields: ['inverter_power'],
        measurements: [measurement],
      )
    end

    describe '#now' do
      subject(:result) { chart.now['inverter_power'] }

      it { is_expected.to have(1.hour / 5.seconds).items }

      it 'contains last data point' do
        last = result.last

        expect(last[1]).to eq(14.0)
        expect(last[0]).to be_within(5.seconds).of(Time.current)
      end
    end

    describe '#year' do
      subject(:result) { chart.year(beginning)['inverter_power'] }

      it { is_expected.to have(12).items }

      it 'contains last and first data point' do
        expect(result.first).to eq([beginning + 1.hour, 2.0])
        expect(result.last).to eq(
          [beginning.end_of_year.beginning_of_month + 1.hour, 12.0],
        )
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

    describe '#now' do
      subject(:now) { chart.now }

      it 'returns key for each requested field' do
        expect(now.keys).to eq(%w[bat_power_minus bat_power_plus])
      end

      describe 'bat_power_plus' do
        subject(:result) { now['bat_power_plus'] }

        it { is_expected.to have(1.hour / 5.seconds).items }

        it 'contains last data point' do
          last = result.last

          expect(last[1]).to eq(2.0)
          expect(last[0]).to be_within(5.seconds).of(Time.current)
        end
      end
    end

    describe '#year' do
      subject(:year) { chart.year(beginning) }

      it 'returns key for each requested field' do
        expect(year.keys).to eq(%w[bat_power_minus bat_power_plus])
      end

      describe 'bat_power_plus' do
        subject(:result) { year['bat_power_plus'] }

        it { is_expected.to have(12).items }

        it 'contains last and first data point' do
          expect(result.first).to eq([beginning + 1.hour, 0.2])
          expect(result.last).to eq(
            [beginning.end_of_year.beginning_of_month + 1.hour, 1.2],
          )
        end
      end
    end
  end
end
