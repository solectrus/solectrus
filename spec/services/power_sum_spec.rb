describe PowerSum do
  let(:peak) { described_class.new(sensors: %i[inverter_power]) }

  before do
    travel_to '2024-06-05 12:00' # Wednesday

    sample_data beginning: Date.yesterday.beginning_of_day, range: 24.hours
    sample_data beginning: Date.current.beginning_of_day, range: 12.hours
  end

  describe '#call' do
    subject { peak.call(timeframe).first[:inverter_power].round }

    context 'when past day' do
      let(:timeframe) { Timeframe.new(date) }
      let(:date) { Date.yesterday.to_fs(:iso8601) }

      it { is_expected.to eq(24_000) }
    end

    context 'when current day' do
      let(:timeframe) { Timeframe.day }

      it { is_expected.to eq(12_000) }
    end

    context 'when current week' do
      let(:timeframe) { Timeframe.week }

      it { is_expected.to eq(36_000) }
    end

    context 'when current month' do
      let(:timeframe) { Timeframe.month }

      it { is_expected.to eq(36_000) }
    end

    context 'when current year' do
      let(:timeframe) { Timeframe.year }

      it { is_expected.to eq(36_000) }
    end
  end

  private

  def sample_data(beginning:, range:)
    influx_batch do
      0.step(range, 5.seconds) do |index|
        add_influx_point(
          name: measurement_inverter_power,
          time: beginning + index.seconds,
          fields: {
            field_inverter_power => 1000,
          },
        )
      end
    end
  end
end
