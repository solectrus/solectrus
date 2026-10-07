describe Sensor::Chart::WallboxCosts do
  subject(:chart) { described_class.new(timeframe:) }

  let(:timeframe) { Timeframe.now }

  before do
    stub_feature(:car, :power_splitter)
    freeze_time

    influx_batch do
      { wallbox_power: 11_000.0, wallbox_power_grid: 4000.0 }.each do |sensor, value|
        add_influx_point(
          name: Sensor::Config.measurement(sensor),
          fields: { Sensor::Config.field(sensor) => value },
          time: 30.minutes.ago,
        )
      end
    end

    allow(Price).to receive(:at).with(hash_including(name: :electricity)).and_return(BigDecimal('0.4'))
    allow(Price).to receive(:at).with(hash_including(name: :feed_in)).and_return(BigDecimal('0.1'))
  end

  # Stacked from the bottom up: PV, grid. The tooltip adds up both shares,
  # like the costs of the heat pump.
  it 'stacks the PV and the grid share, which the tooltip adds up' do
    expect(chart.data[:datasets]).to match(
      [
        hash_including(id: 'wallbox_costs_pv', stack: 'WallboxCosts', summed: true),
        hash_including(id: 'wallbox_costs_grid', stack: 'WallboxCosts', summed: true),
      ],
    )
  end
end
