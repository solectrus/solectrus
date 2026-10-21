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
      max_range: (304 if cars.one?),
      spans:,
    )
  end

  def spans = nil

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

  # The rows below the distance: each label with its value
  def rows = html.css(':has(> .flex > .truncate)')

  def row_texts = rows.map { |row| row.css('.truncate, .truncate + span').map { it.text.squish } }

  it 'shows the driving cost, its rate, the consumption and the range one below the other' do
    expect(row_texts).to eq(
      [
        [I18n.t('car_breakdown.costs'), '373 €'],
        [I18n.t('car_breakdown.cost_rate'), '3.77 €'],
        [I18n.t('car_breakdown.consumption_rate'), '21.2 kWh'],
        [I18n.t('car_breakdown.range'), '304 km'],
      ],
    )
  end

  it 'loads the chart of each row' do
    expect(rows.map { it.at_css('> .flex')['data-stats-with-chart--component-sensor-name-param'] }).to eq(
      %w[car_driving_costs car_cost_rate car_consumption_rate car_max_range],
    )
  end

  it 'has no bars without a span' do
    expect(html.css('svg[style]')).to be_empty
  end

  context 'with the spans of the periods' do
    # The lowest value in 2023, the highest in 2024 or in the given year
    def span(min, max, max_year: '2024') = Car::Spans::Span.new(min:, max:, min_timeframe: Timeframe.new('2023'), max_timeframe: Timeframe.new(max_year))

    def max_range_span = span(280.0, 320.0)

    def spans = instance_double(Car::Spans, cost_per_100km: span(3.7, 4.5), consumption_per_100km: span(18.0, 21.5), max_range: max_range_span)

    def ends(row) = row.css('.justify-between.tabular-nums > *')

    # The ends of each bar, the position of its mark and the color of the
    # mark
    def bars
      rows.filter_map do |row|
        mark = row.at_css('svg[style]') or next
        [*ends(row).map { it.children.first.text.strip }, mark['style'][/[\d.]+%/], mark['class'][/text-signal-\w+/]]
      end
    end

    # The good end is on the right: a low rate, but a high range
    it 'places the rates and the range between the lowest and the highest value, in the color of their third' do
      expect(bars).to eq(
        [
          ['4.50 €', '3.70 €', '90.7%', 'text-signal-positive'],
          ['21.5 kWh', '18.0 kWh', '9.1%', 'text-signal-negative'],
          ['280 km', '320 km', '60.0%', 'text-signal-warning'],
        ],
      )
    end

    # The range is good on the right, so the lowest value stands on the left
    it 'names the period of each end and links to it with the chart of the row' do
      range_ends = ends(rows.last)

      expect(range_ends.map { it.css('[data-tooltip-target="html"] > div').map(&:text) }).to eq([['2023', 'Lowest value'], ['2024', 'Highest value']])
      expect(range_ends.pluck('href')).to eq(%w[/cars/car_max_range/2023 /cars/car_max_range/2024])
    end

    context 'when the shown year has the highest range' do
      def max_range_span = span(280.0, 320.0, max_year: '2025')

      it 'says so, without a link to the same page' do
        shown = ends(rows.last).last

        expect(shown.css('[data-tooltip-target="html"] > div').map(&:text)).to eq(['2025', 'Highest value', 'That is this year.'])
        expect(shown.name).to eq('span')
      end
    end
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

  it 'gives the visits a title' do
    allow(report).to receive(:visit_counts).and_return(visits: 2, places: 1)
    Sensor::Config.setup(env.merge('INFLUX_SENSOR_CAR_LATITUDE_1' => 'Trabant:latitude', 'INFLUX_SENSOR_CAR_LONGITUDE_1' => 'Trabant:longitude'))

    expect(html.text.squish).to include(I18n.t('car_breakdown.on_the_road'))
  ensure
    Sensor::Config.setup(ENV)
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
        spans:,
      )
    end

    it 'says why the driving cost is missing' do
      expect(calculations.sole).to include('100 km at least')
    end

    it 'shows a dash for the driving cost and no cost rate' do
      expect(row_texts.first(2)).to eq([[I18n.t('car_breakdown.costs'), '–'], [I18n.t('car_breakdown.consumption_rate'), '–']])
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
        spans:,
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

  describe 'the visits' do
    let(:cars) { [Car.configured.first] }

    def places_badge = html.at_css('a[href="/cars/1/places/2025"]')

    before do
      Sensor::Config.setup(
        env.merge(
          'INFLUX_SENSOR_CAR_LATITUDE_1' => 'Trabant:latitude',
          'INFLUX_SENSOR_CAR_LONGITUDE_1' => 'Trabant:longitude',
        ),
      )
      allow(report).to receive(:visit_counts).and_return(visits: 2, places: 1)
    end

    after { Sensor::Config.setup(ENV) }

    context 'with the admin' do
      before { allow(vc_test_controller).to receive(:admin?).and_return(true) }

      it 'counts the places of the visits' do
        expect(places_badge.css('span').map { it.text.squish }).to eq(%w[Locations 1])
      end

      it 'links the places to their map, and not the visits to their list' do
        hrefs = html.css('a[href^="/cars/1/"]').pluck('href')

        expect(hrefs).to include('/cars/1/places/2025')
        expect(hrefs).not_to include('/cars/1/visits/2025')
      end
    end

    context 'with a guest' do
      before { allow(vc_test_controller).to receive(:admin?).and_return(false) }

      it 'counts the places, too' do
        expect(places_badge.css('span').map { it.text.squish }).to eq(%w[Locations 1])
      end
    end
  end
end
