describe StatsWithChart::Component, type: :component do
  def interval(**)
    described_class.new(sensor_name: :car_range, timeframe: Timeframe.now, **).refresh_options[:'stats-with-chart--component-interval-value']
  end

  before { allow(Influx::PollInterval).to receive(:current).and_return(5.seconds) }

  it 'refreshes the live view at the rate of the data' do
    expect(interval).to eq(5.seconds)
  end

  # The values of a car change slowly, unlike the power of the house
  it 'refreshes less often with a minimum interval' do
    expect(interval(min_interval: 30.seconds)).to eq(30.seconds)
  end
end
