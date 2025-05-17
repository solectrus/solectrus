describe ConsumptionChart do
  let(:chart) { described_class.new }

  let(:beginning) { 1.year.ago.beginning_of_year }

  before do
    freeze_time

    influx_batch do
      12.times do |index|
        add_influx_point name: measurement_inverter_power_1,
                         fields: {
                           field_inverter_power_1 => (index + 1) * 100,
                           field_grid_export_power => (index + 1) * 50,
                         },
                         time: (beginning + index.month).end_of_month
        add_influx_point name: measurement_inverter_power_1,
                         fields: {
                           field_inverter_power_1 => (index + 1) * 100,
                           field_grid_export_power => (index + 1) * 50,
                         },
                         time: (beginning + index.month).beginning_of_month

        create_summary(
          date: (beginning + index.month).beginning_of_month.to_date,
          values: [
            [:inverter_power_1, :sum, (index + 1) * 100],
            [:grid_export_power, :sum, (index + 1) * 50],
          ],
        )
      end

      add_influx_point name: measurement_inverter_power_1,
                       fields: {
                         field_inverter_power_1 => 2_000,
                         field_grid_export_power => 500,
                       },
                       time: 5.seconds.ago
    end
  end

  describe '#call' do
    subject(:result) { chart.call(timeframe) }

    context 'when timeframe is "now"' do
      let(:timeframe) { Timeframe.now }

      it { is_expected.to have(1.hour / 30.seconds).items }

      it 'contains last data point' do
        timestamp, value = result.last

        expect(value).to eq(75.0) # (2000 - 500) / 2000
        expect(timestamp).to be_within(30.seconds).of(Time.current)
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
