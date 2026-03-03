describe Sensor::Chart::HeatpumpCosts do
  subject(:chart) { described_class.new(timeframe:) }

  let(:timeframe) { Timeframe.now }
  let(:query_series) { instance_double(Sensor::Query::Series, call: series) }
  let(:electricity_price) { 0.4 }
  let(:feed_in_price) { 0.1 }
  let(:series) do
    now = Time.current.change(sec: 0)

    Sensor::Data::Series.new(
      {
        %i[heatpump_power avg avg] => {
          now => 1000.0,
          now + 5.minutes => 2000.0,
        },
        %i[heatpump_power_grid avg avg] => {
          now => 400.0,
          now + 5.minutes => 1500.0,
        },
      },
      timeframe:,
    )
  end

  before do
    allow(Sensor::Query::Series).to receive(:new).and_return(query_series)
    allow(Price).to receive(:at).with(hash_including(name: :electricity)).and_return(electricity_price)
    allow(Price).to receive(:at).with(hash_including(name: :feed_in)).and_return(feed_in_price)
  end

  it 'builds stacked heat pump costs from grid and pv shares in short timeframes' do
    data = chart.data
    grid_dataset = data[:datasets].first
    pv_dataset = data[:datasets].second

    expect(grid_dataset[:id]).to eq('heatpump_costs_grid')
    expect(grid_dataset[:stack]).to eq('HeatpumpCosts')
    expect(grid_dataset[:data]).to eq([0.16, 0.6])

    expect(pv_dataset[:id]).to eq('heatpump_costs_pv')
    expect(pv_dataset[:stack]).to eq('HeatpumpCosts')
    expect(pv_dataset[:data]).to eq([0.06, 0.05])
  end
end
