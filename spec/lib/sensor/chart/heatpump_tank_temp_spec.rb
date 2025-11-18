describe Sensor::Chart::HeatpumpTankTemp do
  subject(:chart) { described_class.new(timeframe:) }

  let(:timeframe) { Timeframe.new('2025-W10') }

  before do
    stub_feature(:heatpump)

    create_summary(
      date: '2025-03-03',
      values: [
        [:heatpump_tank_temp, :min, 30],
        [:heatpump_tank_temp, :max, 55],
      ],
    )

    create_summary(
      date: '2025-03-07',
      values: [
        [:heatpump_tank_temp, :min, 28],
        [:heatpump_tank_temp, :max, 52],
      ],
    )
  end

  it 'builds labels for every day' do
    expect(chart.data[:labels].length).to eq(7)
  end

  it 'builds dataset with min/max range data' do
    chart.data[:datasets].tap do |datasets|
      expect(datasets.length).to eq(1)

      datasets.first.tap do |dataset|
        expect(dataset[:id]).to eq(:heatpump_tank_temp)
        expect(dataset[:data]).to include([30, 55])
      end
    end
  end
end
