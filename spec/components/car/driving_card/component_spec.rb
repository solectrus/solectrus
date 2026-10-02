describe Car::DrivingCard::Component, type: :component do
  subject(:html) { render_inline(described_class.new(balance:, timeframe:)) }

  let(:timeframe) { Timeframe.new('2025') }
  let(:driving) do
    Car::DailyRates::Totals.new(distance: 9877, energy_wh: 2_092_000, cost_distance: 9877, cost: 372.8)
  end
  let(:balance) do
    instance_double(
      Car::Balance,
      car_distance: 9877,
      car_km_per_day: 27.1,
      car_driving_costs: 372.8,
      car_cost_per_100km: 3.77,
      car_consumption_per_100km: 0.212,
      driving:,
      cars: [Car.new(id: 1)],
    )
  end

  before do
    allow(Car::DrivingCostTooltip::Component).to receive(:new).and_return(nil)
  end

  it 'shows the distance with its average for each day' do
    expect(html.text.squish).to include('9,877', 'Ø 27 km/day')
  end

  it 'shows the driving cost and the two rates' do
    expect(html.text.squish).to include('373', '3.77', '21.2')
  end

  it 'loads the rate charts' do
    urls = html.css('a').filter_map { it['data-stats-with-chart--component-chart-url-param'] }

    expect(urls).to include(a_string_including('car_cost_rate'), a_string_including('car_consumption_rate'))
  end

  context 'with a day' do
    let(:timeframe) { Timeframe.new('2025-06-15') }

    it 'opens no rate chart' do
      urls = html.css('a').filter_map { it['data-stats-with-chart--component-chart-url-param'] }

      expect(urls).not_to include(a_string_including('car_cost_rate'))
    end
  end
end
