describe Car::DrivingCard::Component, type: :component do
  subject(:html) { render_inline(described_class.new(report:)) }

  let(:timeframe) { Timeframe.new('2025') }
  let(:driving) do
    Car::Driving::Totals.new(distance: 9877, energy_wh: 2_092_000, cost_distance: 9877, cost: 372.8)
  end
  let(:car_distance) { 9877 }
  let(:cars) { [Car.new(id: 1)] }
  let(:report) do
    instance_double(
      Car::Report,
      timeframe:,
      distance: car_distance,
      km_per_day: 27.1,
      driving_cost: 372.8,
      driving:,
      car: (cars.sole if cars.one?),
      cars:,
      max_range: 304,
    )
  end

  # The car has an odometer, and its range and state of charge give the
  # maximum range
  def env = ENV.to_h.merge('INFLUX_SENSOR_CAR_ODOMETER_1' => 'Trabant:mileage', 'INFLUX_SENSOR_CAR_RANGE_1' => 'Trabant:range')

  before { Sensor::Config.setup(env) }

  # The tooltips of the driving cost, the cost rate and the consumption rate,
  # with a space between the cells
  def tooltips
    html.css('[data-tooltip-target="html"]').map do |tooltip|
      tooltip.css('td, p').map { it.text.squish }.compact_blank.join(' ')
    end
  end

  def label(key) = I18n.t("sensors.#{key}")

  # The tooltips of the driving cost and the rates, without the one of the
  # range, which has no calculation
  def calculations = tooltips.reject { it.include?('The range on a full battery') }

  it 'shows the distance with its average for each day' do
    expect(html.text.squish).to include('9,877', 'Ø 27 km/day')
  end

  # The cells of the row of the driving cost: each number with its caption
  def cost_cells = html.css('.divide-x > [data-controller="tooltip"]')

  it 'shows the driving cost and its rate side by side, each with its own chart' do
    expect(cost_cells.first.parent.parent.at_css('span').text.squish).to eq(I18n.t('car_breakdown.costs'))
    expect(cost_cells.map { it.xpath('span').map { it.text.squish } }).to eq(
      [['373 €', I18n.t('car_breakdown.in_total')], ['3.77 €', I18n.t('car_breakdown.avg_per_100km')]],
    )
    expect(cost_cells.pluck('data-stats-with-chart--component-sensor-name-param')).to eq(%w[car_driving_costs car_cost_rate])
  end

  it 'shows the consumption per 100 km' do
    expect(html.text.squish).to include(I18n.t('car_breakdown.consumption'), '21.2', I18n.t('car_breakdown.per_100km'))
  end

  # The tooltip says that the range is the one on a full battery
  it 'shows the maximum range with its explanation and loads its chart' do
    expect(html.text.squish).to include(I18n.t('car_breakdown.range'), '304 km')
    expect(tooltips).to include(a_string_including('The range on a full battery'))
    expect(html.css('a').filter_map { it['data-stats-with-chart--component-sensor-name-param'] }).to include('car_max_range')
  end

  context 'without a range of the car' do
    def env = ENV.to_h.merge('INFLUX_SENSOR_CAR_ODOMETER_1' => 'Trabant:mileage')

    it 'shows no maximum range' do
      expect(html.text.squish).not_to include(I18n.t('car_breakdown.range'))
      expect(html.css('a').filter_map { it['data-stats-with-chart--component-sensor-name-param'] }).not_to include('car_max_range')
    end
  end

  context 'with the selection "all" of several cars' do
    let(:cars) { [Car.new(id: 1), Car.new(id: 2)] }

    it 'shows no maximum range, because the cars have batteries of their own' do
      expect(html.text.squish).not_to include('304')
    end
  end

  it 'loads the rate charts' do
    urls = html.css('a').filter_map { it['data-stats-with-chart--component-chart-url-param'] }

    expect(urls).to include(a_string_including('car_cost_rate'), a_string_including('car_consumption_rate'))
  end

  # The driving cost is the distance times the cost per 100 km. The rates
  # explain how a day gets its rate, so the two tooltips do not explain each
  # other.
  it 'explains each value without a circle' do
    distance = label(:car_distance_short)
    cost_rate = label(:car_cost_per_100km_short)
    driving_costs = label(:car_driving_costs)

    expect(tooltips).to contain_exactly(
      "#{distance} 9,877 km × #{cost_rate} 3.77 € = #{driving_costs} 373 €",
      a_string_including('the charging cost of the 14 days before and after it, divided by their distance', 'charging losses'),
      a_string_including('the charged energy of the 14 days before and after it, divided by their distance', 'charging losses'),
      a_string_including('The range on a full battery'),
    )
  end

  it 'has no note when all days have a rate' do
    expect(tooltips.join).not_to include('lack charging data')
  end

  context 'with days without a rate' do
    let(:car_distance) { 9887 }

    it 'names their kilometers in each calculation' do
      expect(calculations).to all(include('Without 10 km that lack charging data'))
    end
  end

  context 'without a rate' do
    let(:report) do
      instance_double(
        Car::Report,
        timeframe:,
        distance: car_distance,
        km_per_day: 27.1,
        driving_cost: nil,
        driving: Car::Driving::Totals.empty,
        car: (cars.sole if cars.one?),
        cars:,
        max_range: 304,
      )
    end

    it 'says why the driving cost is missing' do
      expect(calculations.sole).to include('100 km at least')
    end
  end

  # The days have an energy rate, but a session around them has no price
  context 'without a price' do
    let(:driving) { Car::Driving::Totals.new(distance: 9877, energy_wh: 2_092_000, cost_distance: 0.0, cost: 0.0) }
    let(:report) do
      instance_double(
        Car::Report,
        timeframe:,
        distance: car_distance,
        km_per_day: 27.1,
        driving_cost: nil,
        driving:,
        car: (cars.sole if cars.one?),
        cars:,
        max_range: 304,
      )
    end

    it 'names the missing price' do
      expect(tooltips.first).to include('lacks prices')
      expect(tooltips.first).not_to include('100 km at least')
    end
  end

  context 'with a day' do
    let(:timeframe) { Timeframe.new('2025-06-15') }

    it 'opens the charts of the distance and the maximum range, because the others need more than a day' do
      expect(html.css('a').filter_map { it['data-stats-with-chart--component-sensor-name-param'] }).to eq(%w[car_distance car_max_range])
    end
  end
end
