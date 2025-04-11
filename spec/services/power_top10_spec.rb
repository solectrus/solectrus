describe PowerTop10 do
  let(:power_top10) do
    described_class.new(sensor: :inverter_power_1, calc:, desc:)
  end

  before do
    travel_to '2024-06-05 12:30 +02:00' # Wednesday

    # A day in previous year, must NOT affect the result
    sample_data date: Date.new(2023, 12, 31), sum: 120_000, max: 5000
    # => 120 kWh

    # Monday, 2024-06-03 (high value)
    sample_data date: Date.new(2024, 6, 3), sum: 2_400_000, max: 100_000
    # => 2400 kWh

    # Tuesday, 2024-06-04 (medium value)
    sample_data date: Date.new(2024, 6, 4), sum: 1_200_000, max: 50_000
    # => 1200 kWh

    # Wednesday, 2024-06-05 (very high value)
    sample_data date: Date.new(2024, 6, 5), sum: 2_500_000, max: 200_000
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
            { date: Date.new(2024, 1, 1), value: 6_100_000 },
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
            { date: Date.new(2024, 6, 1), value: 6_100_000 },
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
            { date: Date.new(2024, 6, 3), value: 6_100_000 },
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
            { date: Date.new(2024, 6, 5), value: 2_500_000 },
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

  context 'when calculating max' do
    let(:desc) { true }
    let(:calc) { 'max' }

    describe '#years' do
      subject { power_top10.years }

      it do
        is_expected.to eq(
          [
            { date: Date.new(2024, 1, 1), value: 200_000 },
            { date: Date.new(2023, 1, 1), value: 5000 },
          ],
        )
      end
    end

    describe '#months' do
      subject { power_top10.months }

      it do
        is_expected.to eq(
          [
            { date: Date.new(2024, 6, 1), value: 200_000 },
            { date: Date.new(2023, 12, 1), value: 5_000 },
          ],
        )
      end
    end

    describe '#weeks' do
      subject { power_top10.weeks }

      it do
        is_expected.to eq(
          [
            { date: Date.new(2024, 6, 3), value: 200_000 },
            { date: Date.new(2023, 12, 25), value: 5000 },
          ],
        )
      end
    end

    describe '#days' do
      subject { power_top10.days }

      it do
        is_expected.to eq(
          [
            { date: Date.new(2024, 6, 5), value: 200_000 },
            { date: Date.new(2024, 6, 3), value: 100_000 },
            { date: Date.new(2024, 6, 4), value: 50_000 },
            { date: Date.new(2023, 12, 31), value: 5_000 },
          ],
        )
      end
    end
  end

  context 'when using total inverter_power' do
    let(:desc) { true }
    let(:calc) { 'sum' }

    let(:power_top10) do
      described_class.new(sensor: :inverter_power, calc:, desc:)
    end

    describe '#days' do
      subject { power_top10.days }

      it do
        is_expected.to eq(
          [
            { date: Date.new(2024, 6, 5), value: 2_750_000 },
            { date: Date.new(2024, 6, 3), value: 2_640_000 },
            { date: Date.new(2024, 6, 4), value: 1_320_000 },
            { date: Date.new(2023, 12, 31), value: 132_000 },
          ],
        )
      end
    end

    describe '#weeks' do
      subject { power_top10.weeks }

      it do
        is_expected.to eq(
          [
            { date: Date.new(2024, 6, 3), value: 6_710_000 },
            { date: Date.new(2023, 12, 25), value: 132_000 },
          ],
        )
      end
    end
  end

  private

  def sample_data(date:, sum:, max:)
    create_summary(
      date:,
      values: [
        [:inverter_power_1, :sum, sum],
        [:inverter_power_2, :sum, sum * 0.1],
        [:inverter_power_1, :max, max],
      ],
    )
  end
end
