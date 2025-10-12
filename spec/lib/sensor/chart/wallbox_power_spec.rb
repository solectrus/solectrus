describe Sensor::Chart::WallboxPower do
  subject(:chart) { described_class.new(timeframe:) }

  let(:timeframe) { Timeframe.new('2025-W10') }

  before do
    stub_feature(:power_splitter)

    # Monday
    create_summary(
      date: '2025-03-03',
      values: [
        [:wallbox_power, :sum, 17_000],
        [:wallbox_power_grid, :sum, 1_000],
      ],
    )

    # Tuesday
    # No data

    # Wednesday
    # No data

    # Thursday
    # No data

    # Friday
    create_summary(
      date: '2025-03-07',
      values: [
        [:wallbox_power, :sum, 15_000],
        [:wallbox_power_grid, :sum, 4_000],
      ],
    )

    # Saturday
    create_summary(
      date: '2025-03-08',
      values: [
        [:wallbox_power, :sum, 17_000],
        [:wallbox_power_grid, :sum, 1_000],
      ],
    )

    # Sunday
    create_summary(
      date: '2025-03-09',
      values: [
        [:wallbox_power, :sum, 15_000],
        [:wallbox_power_grid, :sum, 13_000],
      ],
    )
  end

  it 'builds label for every day' do
    expect(chart.data[:labels].length).to eq(7)
  end

  it 'builds three datasets with correct sparse data alignment' do
    chart.data[:datasets].tap do |datasets|
      expect(datasets.length).to eq(3)

      datasets.first.tap do |wallbox_power|
        expect(wallbox_power[:id]).to eq(:wallbox_power)
        expect(wallbox_power[:data]).to eq(
          [17_000, nil, nil, nil, 15_000, 17_000, 15_000],
        )
      end

      datasets.second.tap do |wallbox_power_grid|
        expect(wallbox_power_grid[:id]).to eq(:wallbox_power_grid)
        expect(wallbox_power_grid[:data]).to eq(
          [1_000, nil, nil, nil, 4_000, 1_000, 13_000],
        )
      end

      datasets.third.tap do |wallbox_power_pv|
        expect(wallbox_power_pv[:id]).to eq(:wallbox_power_pv)
        expect(wallbox_power_pv[:data]).to eq(
          [16_000, nil, nil, nil, 11_000, 16_000, 2_000],
        )
      end
    end
  end
end
