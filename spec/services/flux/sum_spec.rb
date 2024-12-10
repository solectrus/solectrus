describe Flux::Sum do
  let(:sum) { described_class.new(sensors: %i[inverter_power]) }

  before do
    travel_to '2024-06-05 12:30 +02:00' # Wednesday

    # A day in previous year, must NOT affect the result
    sample_data beginning: Date.new(2023, 12, 31).beginning_of_day,
                range: 24.hours,
                value: 5

    # Monday, 2024-06-03 (high value)
    sample_data beginning: Date.new(2024, 6, 3).beginning_of_day,
                range: 24.hours,
                value: 100

    # Tuesday, 2024-06-04 (medium value)
    sample_data beginning: Date.new(2024, 6, 4).beginning_of_day,
                range: 24.hours,
                value: 50

    # Wednesday, 2024-06-05 (very high value)
    sample_data beginning: Date.new(2024, 6, 5).beginning_of_day,
                range: 12.5.hours,
                value: 200
  end

  describe '#call' do
    subject { sum.call(timeframe:)[:inverter_power].fdiv(1000).round }

    context 'when Monday' do
      let(:timeframe) { Timeframe.new('2024-06-03') }

      it { is_expected.to eq(2400) } # 100 kW for 24 hours
    end

    context 'when Tuesday' do
      let(:timeframe) { Timeframe.new('2024-06-04') }

      it { is_expected.to eq(1200) } # 50 kW for 24 hours
    end

    context 'when Wednesday' do
      let(:timeframe) { Timeframe.new('2024-06-05') }

      it { is_expected.to eq(2500) } # 200 kW for 12.5 hours
    end

    context 'when current week' do
      let(:timeframe) { Timeframe.new('2024-W23') }

      it { is_expected.to eq(6100) } # Mo + Tu + We = 2400 + 1200 + 2500
    end

    context 'when current month' do
      let(:timeframe) { Timeframe.new('2024-06') }

      it { is_expected.to eq(6100) } # Mo + Tu + We = 2400 + 1200 + 2500
    end

    context 'when last year' do
      let(:timeframe) { Timeframe.new('2023') }

      it { is_expected.to eq(120) } # 5 kW in the last 24 hours of 2023
    end

    context 'when current year' do
      let(:timeframe) { Timeframe.new('2024') }

      it { is_expected.to eq(6100) } # Mo + Tu + We = 2400 + 1200 + 2500
    end
  end

  private

  def sample_data(beginning:, range:, value:)
    influx_batch do
      time = beginning
      ending = beginning + range

      while time < ending
        add_influx_point(
          name: measurement_inverter_power,
          time:,
          fields: {
            field_inverter_power => value * 1000,
          },
        )

        time += 5.seconds
      end
    end
  end
end
