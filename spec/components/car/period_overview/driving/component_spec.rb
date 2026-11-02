describe Car::PeriodOverview::Driving::Component, type: :component do
  subject(:html) { render_inline(described_class.new(report:)) }

  def card = html.at_css('section[aria-label="Driving"]')

  # The value and the label of each cell below the distance
  def cells = card.css('> div:last-child > *').map { |cell| cell.css('> span > span').map { it.text.squish } }

  # The charts that a click on a figure loads
  def charts = html.css('[data-stats-with-chart--component-sensor-name-param]').pluck('data-stats-with-chart--component-sensor-name-param')

  # The text of the tooltip of the figure of a sensor
  def tooltip(sensor_name) = card.at_css(%([data-stats-with-chart--component-sensor-name-param="#{sensor_name}"] [data-tooltip-target="html"])).text.squish

  def comparison_bar = html.at_css('section + * [data-controller="car--share-bar--component"]')

  def comparison_tooltip = comparison_bar.parent.at_css('[data-tooltip-target="html"]').text.squish

  # The share of the width and the shown label of each part of the bar
  def bar_parts = comparison_bar.css('> span').map { [it['style'][/flex: ([\d.]+)/, 1].to_f, it.css('> span').map { it.text.squish }] }

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

  it 'leads with the distance, and below it the cost and the rates per 100 km' do
    expect(card.text.squish).to include('9,877 km')
    expect(cells).to eq([['373 €'], ['21.2 kWh', 'per 100 km'], ['3.77 €', 'per 100 km']])
  end

  it 'shows the average distance of a day in the tooltip of the distance' do
    expect(tooltip('car_distance')).to eq('Distance drivenØ per day27 km')
  end

  it 'loads the chart of each figure' do
    expect(charts).to eq(%w[car_distance car_driving_costs car_consumption_rate car_cost_rate])
  end

  it 'leaves the cost per 100 km out of the tooltip of the cost, which has a cell of its own' do
    expect(tooltip('car_driving_costs')).to eq('Energy cost of driving')
  end

  # The cell shows the rate, so its tooltip does not repeat it
  it 'leaves the rate out of the tooltip of each rate' do
    tooltips = %w[car_consumption_rate car_cost_rate].map { tooltip(it) }

    expect(tooltips).to all(satisfy { it.exclude?('21.2 kWh') && it.exclude?('3.77 €') })
    expect(tooltips.first).to include('charging losses')
  end

  # The rates come from the days around each day driven
  it 'names the window of the rates in the tooltips of the rates' do
    expect(%w[car_consumption_rate car_cost_rate].map { tooltip(it) }).to all(include('14 days before and after'))
  end

  # Without fuel prices or a combustion car, there is nothing to compare
  it 'keeps the comparison as an empty track without a comparison' do
    expect(comparison_bar.css('[data-car--share-bar--component-target]')).to be_empty
    expect(html.at_css('a[href*="/savings"]')).to be_nil
  end

  it 'says in the tooltip of the empty track what the comparison needs' do
    expect(comparison_tooltip).to eq('Savings against a combustion carThe comparison needs a combustion car in the settings of the car, and the fuel prices.')
  end

  context 'with a comparison' do
    let(:comparison) { instance_double(Car::Comparison, ready?: true) }
    let(:amounts) { instance_double(Car::ComparisonAmounts, car_cost: 25, combustion_cost: 100, savings: 75, precision: 0) }

    before do
      allow(report).to receive_messages(savings?: true, comparison:)
      allow(Car::ComparisonAmounts).to receive(:new).with(comparison).and_return(amounts)
    end

    # The whole bar is the cost of the combustion car
    it 'shows the cost of the car beside the savings, and links to the comparison' do
      expect(html.at_css('a[href="/cars/savings/2025"]')).to eq(comparison_bar.parent)
      expect(bar_parts).to eq([[25.0, []], [75.0, ['75 € saved', '75 €']]])
    end

    it 'names both cars and the savings in the tooltip' do
      tooltip = comparison_bar.parent.at_css('[data-tooltip-target="html"]').text.squish

      expect(tooltip).to include('Savings against a combustion car', 'EV25 €', 'Combustion car100 €', 'Savings75 €')
    end

    # The whole bar is the cost of the car
    context 'with a loss' do
      let(:amounts) { instance_double(Car::ComparisonAmounts, car_cost: 112, combustion_cost: 100, savings: -12, precision: 0) }

      it 'shows the extra cost beside the cost of the combustion car, in red' do
        expect(bar_parts).to eq([[100.0, []], [12.0, ['12 € more', '12 €']]])
        expect(comparison_bar.at_css('.text-signal-negative-strong')).to be_present
      end
    end

    # The comparison page says what it lacks
    context 'without a compared distance' do
      let(:comparison) { instance_double(Car::Comparison, ready?: false) }

      it 'keeps the bar as an empty track, which links to the comparison' do
        expect(comparison_bar.css('[data-car--share-bar--component-target]')).to be_empty
        expect(html.at_css('a[href="/cars/savings/2025"]')).to be_present
      end

      it 'names the gaps in the tooltip' do
        expect(comparison_tooltip).to end_with('The comparison page names the gaps.')
      end
    end
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

  # A rate needs the charging of the days around a drive
  context 'with a drive without a rate' do
    let(:driving) { Car::Driving::Totals.empty }

    it 'tells what is missing' do
      expect(cells.map(&:first)).to eq(%w[– – –])
      expect(%w[car_driving_costs car_consumption_rate car_cost_rate].map { tooltip(it) }).to all(include('The data is not enough'))
    end
  end

  context 'without a drive' do
    let(:distance) { nil }
    let(:driving) { Car::Driving::Totals.empty }

    it 'says so alone' do
      expect(card.text.squish).to eq('No drives')
      expect(charts).to be_empty
    end

    it 'says in the tooltip of the empty track why it has no savings' do
      expect(comparison_tooltip).to eq('Savings against a combustion carWithout a drive, there is nothing to compare.')
    end
  end
end
