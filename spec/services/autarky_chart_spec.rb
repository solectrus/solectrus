describe AutarkyChart do
  let(:chart) { described_class.new }

  let(:beginning) { 1.year.ago.beginning_of_year }

  before { freeze_time }

  context 'with wallbox_power sensor' do
    before do
      12.times do |index|
        create_summary(
          date: beginning + index.months,
          values: [
            [:house_power, :sum, (index + 1) * 100 * 24], # 100 W for 24 hours
            [:grid_import_power, :sum, (index + 1) * 300 * 24], # 50 W for 24 hours
            [:wallbox_power, :sum, (index + 1) * 500 * 24], # 200 W for 24 hours
          ],
        )
      end

      add_influx_point name: measurement_house_power,
                       fields: {
                         field_house_power => 6_000,
                         field_grid_import_power => 3000,
                         # NOTE: There is no `wallbox_power` in this data point.
                         # This happens when the `csv-importer` was used to import CSV data from SENEC,
                         # which do not contain the `wallbox_power`.
                         # The missing value tests the `if` statement in the query.
                       },
                       time: 5.seconds.ago
    end

    describe '#call' do
      subject(:result) { chart.call(timeframe) }

      context 'when timeframe is "now"' do
        let(:timeframe) { Timeframe.now }

        it { is_expected.to have(1.hour / 30.seconds).items }

        it 'contains last data point' do
          timestamp, value = result.last

          expect(value).to eq(50.0)
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

  context 'without wallbox_power sensor' do
    before do
      allow(SensorConfig.x).to receive(:field) do |arg|
        if arg == :wallbox_power
          nil
        else
          original_method = SensorConfig.x.method(:field).super_method
          original_method.call(arg)
        end
      end

      12.times do |index|
        create_summary(
          date: beginning + index.months,
          values: [
            [:house_power, :sum, (index + 1) * 100 * 24], # 100 W for 24 hours
            [:grid_import_power, :sum, (index + 1) * 50 * 24], # 50 W for 24 hours
          ],
        )
      end

      add_influx_point name: measurement_house_power,
                       fields: {
                         field_house_power => 6_000,
                         field_grid_import_power => 3000,
                       },
                       time: 5.seconds.ago
    end

    describe '#call' do
      subject(:result) { chart.call(timeframe) }

      context 'when timeframe is "now"' do
        let(:timeframe) { Timeframe.now }

        it { is_expected.to have(1.hour / 30.seconds).items }

        it 'contains last data point' do
          timestamp, value = result.last

          expect(value).to eq(50.0)
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
end
