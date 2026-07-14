describe Sensor::Chart::HeatpumpCosts do
  subject(:chart) { described_class.new(timeframe:) }

  let(:timeframe) { Timeframe.now }

  before do
    stub_feature(:heatpump, :power_splitter)
    freeze_time

    influx_batch do
      {
        heatpump_power: 2000.0,
        heatpump_power_grid: 1500.0,
      }.each do |sensor, value|
        add_influx_point(
          name: Sensor::Config.measurement(sensor),
          fields: {
            Sensor::Config.field(sensor) => value,
          },
          time: 30.minutes.ago,
        )
      end
    end

    allow(Price).to receive(:at).with(
      hash_including(name: :electricity),
    ).and_return(BigDecimal('0.4'))
    allow(Price).to receive(:at).with(hash_including(name: :feed_in)).and_return(
      BigDecimal('0.1'),
    )
  end

  # grid share: 1500 * 0.4 / 1000 = 0.60
  # pv share:   (2000 - 1500) * 0.1 / 1000 = 0.05
  it 'builds stacked heat pump costs from grid and pv shares' do
    data = chart.data
    grid_dataset = data[:datasets].first
    pv_dataset = data[:datasets].second

    expect(grid_dataset[:id]).to eq('heatpump_costs_grid')
    expect(grid_dataset[:stack]).to eq('HeatpumpCosts')
    expect(grid_dataset[:data].compact).to all(be_within(0.0001).of(0.6))

    expect(pv_dataset[:id]).to eq('heatpump_costs_pv')
    expect(pv_dataset[:stack]).to eq('HeatpumpCosts')
    expect(pv_dataset[:data].compact).to all(be_within(0.0001).of(0.05))
  end

  it 'produces Float values' do
    values = chart.data[:datasets].flat_map { |dataset| dataset[:data] }.compact

    expect(values).to all(be_a(Float))
  end
end
