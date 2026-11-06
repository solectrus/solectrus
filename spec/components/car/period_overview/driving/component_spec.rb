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
      sessions: ChargingSession::Sums.empty.with(rows: 1, cost: 401.2),
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

  # A phone shows the distance as the only number of the card, so its
  # tooltip has the figures of the cells, in a group each, and one note
  it 'groups the distance, the cost and the consumption in the tooltip of the distance' do
    template = card.at_css('[data-stats-with-chart--component-sensor-name-param="car_distance"] [data-tooltip-target="html"]')
    groups = Nokogiri::HTML.fragment(template.inner_html).css('.tooltip-group').map { it.text.squish }

    expect(groups[0..2]).to eq(['Distance driven9,877 kmØ per day27 km', 'Energy cost373 €per 100 km3.77 €', 'Usage per 100 km21.2 kWh'])
    expect(groups.last).to start_with('The values per 100 km count the charging of the 14 days')
  end

  # The sheet of a phone loads the chart of a row (see tooltipSheet.ts)
  it 'links each figure in the tooltip of the distance to its chart' do
    template = card.at_css('[data-stats-with-chart--component-sensor-name-param="car_distance"] [data-tooltip-target="html"]')
    links = Nokogiri::HTML.fragment(template.inner_html).css('a.tooltip-link').pluck('href')

    expect(links).to eq(%w[/cars/car_distance/2025 /cars/car_distance/2025 /cars/car_driving_costs/2025 /cars/car_cost_rate/2025 /cars/car_consumption_rate/2025])
  end

  # A phone shows the links alone, a wider screen also the figures
  it 'shows the links alone on a phone' do
    expect(card.at_css('> div.lg\\:hidden')).to be_nil
    expect(card.at_css('> div.max-lg\\:hidden')).to be_present
  end

  it 'loads the chart of each figure' do
    expect(charts).to eq(%w[car_distance car_driving_costs car_consumption_rate car_cost_rate])
  end

  it 'leaves the cost per 100 km out of the tooltip of the cost, which has a cell of its own' do
    expect(tooltip('car_driving_costs')).to eq('Energy cost of drivingThe cost of the kilometers driven, based on the cost per 100 km.The difference from the charging cost comes from energy that the car charged on other days.')
  end

  # The card of the charging shows the same number, so there is no difference
  # to explain
  context 'with the same cost as the charging' do
    before { allow(report).to receive(:sessions).and_return(ChargingSession::Sums.empty.with(rows: 1, cost: 373.1)) }

    it 'leaves out why the cost differs from the charging cost' do
      expect(tooltip('car_driving_costs')).to eq('Energy cost of drivingThe cost of the kilometers driven, based on the cost per 100 km.')
    end
  end

  # The cell shows the rate, so its tooltip does not repeat it
  it 'leaves the rate out of the tooltip of each rate' do
    tooltips = %w[car_consumption_rate car_cost_rate].map { tooltip(it) }

    expect(tooltips).to all(satisfy { it.exclude?('21.2 kWh') && it.exclude?('3.77 €') })
    expect(tooltips.first).to include('charging losses')
  end

  # The rates come from the days around each day driven. This comes first,
  # before what only the rate means.
  it 'names the window of the rates first in the tooltips of the rates' do
    expect(%w[car_consumption_rate car_cost_rate].map { tooltip(it) }).to all(include('14 days before and after'))
    expect(tooltip('car_consumption_rate').index('14 days')).to be < tooltip('car_consumption_rate').index('charging losses')
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
      expect(comparison_bar.parent['href']).to eq('/cars/savings/2025')
      expect(bar_parts).to eq([[25.0, []], [75.0, ['75 € saved', '75 €']]])
    end

    # A bar above the timeline of a day looks like one of its lanes
    it 'shows the savings as a link in the card in place of the bar on a phone' do
      link = card.at_css('> div.lg\\:hidden > a')

      expect(comparison_bar.parent['class']).to include('max-lg:hidden')
      expect(link['href']).to eq('/cars/savings/2025?sheet=1')
      expect(link['data-turbo-frame']).to eq('modal')
      expect(link.text.squish).to eq('75 € saved')
      expect(card.css('> div.max-lg\\:hidden a[href*="/savings"]')).to be_empty
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
        expect(card.at_css('> div.lg\\:hidden > a').text.squish).to eq('12 € more')
      end
    end

    # The comparison page says what it lacks
    context 'without a compared distance' do
      let(:comparison) { instance_double(Car::Comparison, ready?: false) }

      it 'keeps the bar as an empty track, which links to the comparison' do
        expect(comparison_bar.css('[data-car--share-bar--component-target]')).to be_empty
        expect(comparison_bar.parent['href']).to eq('/cars/savings/2025')
      end

      it 'names the savings without an amount on a phone' do
        expect(card.at_css('> div.lg\\:hidden > a').text.squish).to eq('Savings')
      end

      it 'names the gaps in the tooltip' do
        expect(comparison_tooltip).to end_with('The comparison page names the gaps.')
      end
    end
  end

  # A day has the timeline of the day in place of the charts
  context 'with a day' do
    before { allow(report).to receive(:timeframe).and_return(Timeframe.new('2025-06-20')) }

    it 'loads no chart' do
      expect(charts).to be_empty
      expect(card.css('[data-tooltip-target="html"]').map(&:inner_html).join).not_to include('tooltip-link')
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
