describe PowerTop10 do
  let(:power_top10) do
    described_class.new(sensor: :inverter_power, calc:, desc:)
  end

  before do
    travel_to '2024-06-05 12:30 +02:00' # Wednesday

    # A day in previous year, must NOT affect the result
    sample_data beginning: Date.new(2023, 12, 31).beginning_of_day,
                range: 24.hours,
                value: 5
    # => 120 kWh

    # Monday, 2024-06-03 (high value)
    sample_data beginning: Date.new(2024, 6, 3).beginning_of_day,
                range: 24.hours,
                value: 100
    # => 2400 kWh

    # Tuesday, 2024-06-04 (medium value)
    sample_data beginning: Date.new(2024, 6, 4).beginning_of_day,
                range: 24.hours,
                value: 50
    # => 1200 kWh

    # Wednesday, 2024-06-05 (very high value)
    sample_data beginning: Date.new(2024, 6, 5).beginning_of_day,
                range: 12.5.hours,
                value: 200
    # => 2500 kWh
  end

  context 'when descending' do
    let(:desc) { true }
    let(:calc) { 'sum' }

    describe '#years' do
      subject { power_top10.years }

      it do
        is_expected.to eq(
          [
            { date: Date.new(2024, 1, 1), value: 6_200_000 },
            { date: Date.new(2023, 1, 1), value: 120_000 },
          ],
        )
      end
    end

    describe '#months' do
      subject { power_top10.months }

      it do
        is_expected.to eq(
          [
            { date: Date.new(2024, 6, 1), value: 6_200_000 },
            { date: Date.new(2023, 12, 1), value: 120_000 },
          ],
        )
      end
    end

    describe '#weeks' do
      subject { power_top10.weeks }

      it do
        is_expected.to eq(
          [
            { date: Date.new(2024, 6, 3), value: 6_200_000 },
            { date: Date.new(2023, 12, 25), value: 120_000 },
          ],
        )
      end
    end

    describe '#days' do
      subject { power_top10.days }

      it do
        is_expected.to eq(
          [
            { date: Date.new(2024, 6, 5), value: 2_600_000 }, # Not exactly 2500 kWh (!)
            { date: Date.new(2024, 6, 3), value: 2_400_000 },
            { date: Date.new(2024, 6, 4), value: 1_200_000 },
            { date: Date.new(2023, 12, 31), value: 120_000 },
          ],
        )
      end
    end
  end

  context 'when ascending' do
    let(:desc) { false }
    let(:calc) { 'sum' }

    describe '#years' do
      subject { power_top10.years }

      it { is_expected.to eq([{ date: Date.new(2023, 1, 1), value: 120_000 }]) }
    end

    describe '#months' do
      subject { power_top10.months }

      it do
        is_expected.to eq([{ date: Date.new(2023, 12, 1), value: 120_000 }])
      end
    end

    describe '#weeks' do
      subject { power_top10.weeks }

      it do
        is_expected.to eq([{ date: Date.new(2023, 12, 25), value: 120_000 }])
      end
    end

    describe '#days' do
      subject { power_top10.days }

      it do
        is_expected.to eq(
          [
            { date: Date.new(2023, 12, 31), value: 120_000 },
            { date: Date.new(2024, 6, 4), value: 1_200_000 },
            { date: Date.new(2024, 6, 3), value: 2_400_000 },
          ],
        )
      end
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
