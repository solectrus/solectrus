describe PowerSum do
  let(:power_sum) { described_class.new(sensors: %i[inverter_power]) }

  before do
    travel_to '2024-06-05 12:00' # Wednesday

    # A day in previous year, must not affect the result
    sample_data beginning: Date.new(2023, 12, 31).beginning_of_day,
                range: 24.hours

    # Monday (high value)
    sample_data beginning: Date.new(2024, 6, 3).beginning_of_day,
                range: 24.hours,
                value: 10

    # Tuesday
    sample_data beginning: Date.new(2024, 6, 4).beginning_of_day,
                range: 24.hours

    # Wednesday
    sample_data beginning: Date.new(2024, 6, 5).beginning_of_day,
                range: 12.hours
  end

  describe '#call' do
    subject do
      power_sum.call(timeframe).first[:inverter_power].fdiv(1000).round(1)
    end

    context 'when past day' do
      let(:timeframe) { Timeframe.new(date) }
      let(:date) { Date.yesterday.to_fs(:iso8601) }

      it { is_expected.to eq(24) } # 1 kW for 24 hours
    end

    context 'when current day' do
      let(:timeframe) { Timeframe.day }

      it { is_expected.to eq(12) } # 1 kW for 12 hours
    end

    context 'when yesterday' do
      let(:timeframe) { Timeframe.new(Date.yesterday.iso8601) }

      it { is_expected.to eq(24) } # 1 kW for 24 hours
    end

    context 'when current week' do
      let(:timeframe) { Timeframe.week }

      it { is_expected.to eq(276) } # 1 kW for 24+12 hours and 10 kW for 24 hours
    end

    context 'when current month' do
      let(:timeframe) { Timeframe.month }

      it { is_expected.to eq(276) } # 1 kW for 24+12 hours and 10 kW for 24 hours
    end

    context 'when current year' do
      let(:timeframe) { Timeframe.year }

      it { is_expected.to eq(276) } # 1 kW for 24+12 hours and 10 kW for 24 hours
    end
  end

  private

  def sample_data(beginning:, range:, value: 1)
    influx_batch do
      0.step(range, 5.seconds) do |index|
        add_influx_point(
          name: measurement_inverter_power,
          time: beginning + (index - 1).seconds,
          fields: {
            field_inverter_power => value * 1000,
          },
        )
      end
    end
  end
end
