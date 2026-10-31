describe Car::DrivingBox::Component, type: :component do
  subject(:html) { render_inline(described_class.new(report:)) }

  # The row of the figures above the bar
  def row = html.at_css('section > div.rounded-xl > div:first-child')

  # The lead, without a caption
  def lead = row.at_css('> :first-child > span').text.squish

  # The value and the caption of a phone of each figure beside the lead
  def tiles = row.css('> div > *').map { |tile| tile.css('> span').first(2).map { it.text.squish } }

  # The charts that a click on a figure loads
  def charts = html.css('[data-stats-with-chart--component-sensor-name-param]').pluck('data-stats-with-chart--component-sensor-name-param').uniq

  # The text of each tooltip of a figure
  def tooltips = row ? row.css('[data-tooltip-target="html"]').map { it.text.squish } : []

  # The bar of the savings, which links to the comparison
  def savings_bar = html.at_css('section > div.rounded-xl > a[href*="/savings"]')

  # The forms of the label of each part of the bar of the savings
  def bar_labels = savings_bar.css('[role="img"] > span').map { |part| part.css('> span').map { it.text.squish } }

  # The text of the info icon beside the title
  def info = html.at_css('h2 ~ [data-controller="tooltip"] [data-tooltip-target="html"]')&.text&.squish

  # The number and the period of each end of each bar of a span
  def span_ends = html.css('span.justify-between').map { |ends| ends.css('> span').map { it.css('span').map(&:text) } }

  let(:distance) { 9877 }
  let(:driving) { Car::Driving::Totals.new(distance: 9877, energy_wh: 2_092_000, cost_distance: 9877, cost: 372.8) }
  let(:report) do
    instance_double(
      Car::Report,
      timeframe: Timeframe.new('2025'),
      cars: [Car.new(id: 1)],
      car: nil,
      distance:,
      distances: {},
      km_per_day: (27.1 if distance),
      driving:,
      spans: nil,
      savings?: false,
    )
  end

  # The car has an odometer, so the charts of the driving can draw
  before { Sensor::Config.setup(ENV.to_h.merge('INFLUX_SENSOR_CAR_ODOMETER_1' => 'Trabant:mileage')) }

  after { Sensor::Config.setup(ENV) }

  it 'leads with the distance, beside it the energy used and the energy cost' do
    expect(lead).to eq('9,877 km')
    expect(tiles).to eq([['2,092 kWh', 'Energy used'], ['373 €', 'Energy cost']])
  end

  it 'shows the average distance of a day in the tooltip of the distance' do
    expect(tooltips.first).to eq('Distance drivenØ per day27 km')
  end

  it 'loads the chart of each figure' do
    expect(charts).to eq(%w[car_distance car_driving_energy car_driving_costs])
  end

  # Without fuel prices or a combustion car, there is nothing to compare
  it 'has no bar without a comparison' do
    expect(html.css('[data-controller="car--share-bar--component"]')).to be_empty
  end

  context 'with a comparison' do
    let(:comparison) { instance_double(Car::Comparison, ready?: true) }
    let(:amounts) { instance_double(Car::ComparisonAmounts, car_cost: 25, combustion_cost: 100, savings: 75, precision: 0) }

    before do
      allow(report).to receive_messages(savings?: true, comparison:)
      allow(Car::ComparisonAmounts).to receive(:new).with(comparison).and_return(amounts)
    end

    # The amount matters, so the bar shows no ratio
    it 'shows the savings in a bar of its own, which links to the comparison' do
      expect(savings_bar['href']).to eq('/cars/savings/2025')
      expect(bar_labels).to eq([['75 € saved', '75 €']])
    end

    it 'names both cars and the savings in the tooltip' do
      tooltip = savings_bar.at_css('[data-tooltip-target="html"]').text.squish

      expect(tooltip).to include('Savings against a combustion car', 'EV25 €', 'Combustion car100 €', 'Savings75 €')
    end

    context 'with a loss' do
      let(:amounts) { instance_double(Car::ComparisonAmounts, car_cost: 112, combustion_cost: 100, savings: -12, precision: 0) }

      it 'shows the loss in red' do
        expect(bar_labels).to eq([['12 € more', '12 €']])
        expect(savings_bar.at_css('.text-signal-negative')).to be_present
      end
    end

    # The comparison page says what it lacks
    context 'without a compared distance' do
      let(:comparison) { instance_double(Car::Comparison, ready?: false) }

      it 'keeps the bar as an empty track' do
        expect(savings_bar.css('[data-car--share-bar--component-target]')).to be_empty
      end
    end
  end

  # The rates come from the days around each day driven
  it 'names the window of the rates in an info icon beside the title' do
    expect(info).to include('14 days before and after')
  end

  # A low rate is good, so the good end is the lowest on the right
  context 'with the span of the periods' do
    let(:span) { ->(min, max, min_timeframe, max_timeframe) { Car::Spans::Span.new(min:, max:, min_timeframe: Timeframe.new(min_timeframe), max_timeframe: Timeframe.new(max_timeframe)) } }

    before do
      allow(report).to receive(:spans).and_return(
        instance_double(Car::Spans, cost_per_100km: span.call(1.06, 10.67, '2023', '2021'), consumption_per_100km: span.call(9.31, 38.92, '2024', '2022')),
      )
    end

    it 'shows the ends of each span with their periods in the tooltips, the good end on the right' do
      expect(span_ends).to eq([[%w[38.9 2022], %w[9.3 2024]], [%w[10.67 2021], %w[1.06 2023]]])
    end

    # A sheet lists the lowest and the highest rate, each with a link to its
    # period. The figure is a link itself, so the tooltip is a template.
    it 'lists the lowest and the highest rate with a link to the period for a sheet' do
      rows = html.css('template[data-tooltip-target="html"] .tooltip-sheet-only a.insights-row')

      # The stylesheet sets the parentheses around the period
      expect(rows.map { |row| [row.at_css('.insights-row-main'), row.at_css('.insights-row-value')].map { it.text.squish } }).to eq(
        [['Minimum 2024', '9.3 kWh'], ['Maximum 2022', '38.9 kWh'], ['Minimum 2023', '1.06 €'], ['Maximum 2021', '10.67 €']],
      )
      expect(rows.pluck('href')).to eq(%w[/cars/car_consumption_rate/2024 /cars/car_consumption_rate/2022 /cars/car_cost_rate/2023 /cars/car_cost_rate/2021])
    end
  end

  # A day has the timeline of the day in place of the charts
  context 'with a day' do
    before { allow(report).to receive(:timeframe).and_return(Timeframe.new('2025-06-20')) }

    it 'loads no chart' do
      expect(charts).to be_empty
    end
  end

  # Each figure has its rate per 100 km, and what only this figure means
  it 'shows the rate of each figure in its own tooltip' do
    _distance, consumption, cost = tooltips

    expect(cost).to include('Energy cost', I18n.t('sensors.car_cost_rate'), '3.77 €')
    expect(consumption).to include('Energy used', I18n.t('sensors.car_consumption_rate'), '21.2 kWh', 'charging losses')
  end

  # A rate needs the charging of the days around a drive
  context 'with a drive without a rate' do
    let(:driving) { Car::Driving::Totals.empty }

    it 'tells what is missing' do
      expect(tiles.map(&:first)).to eq(%w[– –])
      expect(tooltips.drop(1)).to all(include('The data is not enough'))
    end
  end

  # A period without a drive says so in the place of the figures, which
  # would be 0 and dashes
  context 'without a drive' do
    let(:distance) { nil }
    let(:driving) { Car::Driving::Totals.empty }

    it 'says so instead of the figures' do
      expect(html.css('section > div').last.text.squish).to eq('No drives')
    end

    it 'loads no chart and names no window of the rates' do
      expect(charts).to be_empty
      expect(info).to be_nil
    end
  end
end
