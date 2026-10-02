describe Car::DrivingCard::Component, type: :component do
  subject(:html) { render_inline(described_class.new(balance:, timeframe:)) }

  let(:timeframe) { Timeframe.new('2025') }
  let(:driving) do
    Car::DailyRates::Totals.new(distance: 9877, energy_wh: 2_092_000, cost_distance: 9877, cost: 372.8)
  end
  let(:car_distance) { 9877 }
  let(:balance) do
    instance_double(
      Car::Balance,
      car_distance:,
      car_km_per_day: 27.1,
      car_driving_costs: 372.8,
      car_cost_per_100km: 3.77,
      car_consumption_per_100km: 0.212,
      driving:,
      cars: [Car.new(id: 1)],
    )
  end

  # The tooltips of the driving cost, the cost rate and the consumption rate,
  # with a space between the cells
  def tooltips
    html.css('[data-tooltip-target="html"]').map do |tooltip|
      tooltip.css('td, p').map { it.text.squish }.compact_blank.join(' ')
    end
  end

  def label(key) = I18n.t("sensors.#{key}")

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

  # The user can multiply the distance by the rate, and divide a sum by the
  # distance
  it 'explains each value with its calculation' do
    distance = label(:car_distance_short)
    cost_rate = label(:car_cost_per_100km_short)
    driving_costs = label(:car_driving_costs)
    consumption_rate = label(:car_consumption_per_100km_short)

    expect(tooltips).to contain_exactly(
      "#{distance} 9,877 km × #{cost_rate} 3.77 € = #{driving_costs} 373 €",
      a_string_starting_with("#{driving_costs} 372.80 € ÷ #{distance} 9,877 km = #{cost_rate} 3.77 €"),
      a_string_starting_with("Energy for driving 2,092 kWh ÷ #{distance} 9,877 km = #{consumption_rate} 21.2 kWh"),
    )
  end

  it 'says that each day of a rate has a window of its own' do
    expect(tooltips.last).to include('Each day therefore takes the rate of the 14 days before and after it', 'charging losses')
  end

  it 'has no note when all days have a rate' do
    expect(tooltips.join).not_to include('lack charging data')
  end

  context 'with days without a rate' do
    let(:car_distance) { 9887 }

    it 'names their kilometers in each calculation' do
      expect(tooltips).to all(include('Without 10 km that lack charging data'))
    end
  end

  context 'without a rate' do
    let(:balance) do
      instance_double(
        Car::Balance,
        car_distance:,
        car_km_per_day: 27.1,
        car_driving_costs: nil,
        car_cost_per_100km: nil,
        car_consumption_per_100km: nil,
        driving: Car::DailyRates::Totals.empty,
        cars: [Car.new(id: 1)],
      )
    end

    it 'says why the driving cost is missing' do
      expect(tooltips.sole).to include('100 km at least')
    end
  end

  context 'with a day' do
    let(:timeframe) { Timeframe.new('2025-06-15') }

    it 'opens no chart, because each needs a whole day' do
      expect(html.css('a')).to be_empty
    end
  end
end
