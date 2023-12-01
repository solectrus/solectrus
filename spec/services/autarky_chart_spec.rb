describe AutarkyChart do
  let(:measurement) { "Test#{described_class}" }
  let(:chart) { described_class.new(measurements: [measurement]) }

  let(:beginning) { 1.year.ago.beginning_of_year }

  before do
    influx_batch do
      12.times do |index|
        add_influx_point name: measurement,
                         fields: {
                           house_power: (index + 1) * 100,
                           grid_power_plus: (index + 1) * 300,
                           wallbox_charge_power: (index + 1) * 500,
                         },
                         time: (beginning + index.month).end_of_month
        add_influx_point name: measurement,
                         fields: {
                           house_power: (index + 1) * 100,
                           grid_power_plus: (index + 1) * 300,
                           wallbox_charge_power: (index + 1) * 500,
                         },
                         time: (beginning + index.month).beginning_of_month
      end

      add_influx_point name: measurement,
                       fields: {
                         house_power: 6_000,
                         grid_power_plus: 3000,
                         # NOTE: There is no `wallbox_charge_power` in this data point.
                         # This happens when the `senec-importer` was used to import CSV data,
                         # which do not contain the `wallbox_charge_power`.
                         # The missing value tests the `if` statement in the query.
                       }
    end
  end

  around { |example| freeze_time(&example) }

  describe '#call' do
    subject(:result) { chart.call(timeframe) }

    context 'when timeframe is "now"' do
      let(:timeframe) { Timeframe.now }

      it { is_expected.to have(1.hour / 20.seconds).items }

      it 'contains last data point' do
        last = result.last

        expect(last[1]).to eq(50.0)
        expect(last.first).to be_within(20.seconds).of(Time.current)
      end
    end

    context 'when timeframe is a year' do
      let(:timeframe) { Timeframe.new(beginning.year.to_s) }

      it { is_expected.to have(12).items }

      it 'contains last and first data point' do
        expect(result.first).to eq([beginning, 50.0])
        expect(result.last).to eq(
          [beginning.end_of_year.beginning_of_month, 50.0],
        )
      end
    end
  end
end
