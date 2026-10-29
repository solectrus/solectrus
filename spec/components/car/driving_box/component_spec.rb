describe Car::DrivingBox::Component, type: :component do
  subject(:html) { render_inline(described_class.new(report:)) }

  # The value and the caption of a phone of each figure
  def tiles = html.css('section > div.grid > *').map { |tile| tile.css('> span').first(2).map { it.text.squish } }

  # The caption of the desktop of each figure with one of its own
  def wide_labels = html.css('section > div.grid > * > span.max-lg\:hidden').map { it.text.squish }

  # The charts that a click on a figure loads
  def charts = html.css('[data-stats-with-chart--component-sensor-name-param]').pluck('data-stats-with-chart--component-sensor-name-param').uniq

  # The text of each tooltip of a figure
  def tooltips = html.css('section > div.grid [data-tooltip-target="html"]').map { it.text.squish }

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
    )
  end

  # The car has an odometer, so the charts of the driving can draw
  before { Sensor::Config.setup(ENV.to_h.merge('INFLUX_SENSOR_CAR_ODOMETER_1' => 'Trabant:mileage')) }

  after { Sensor::Config.setup(ENV) }

  it 'shows the distance with its average of a day, the energy used and the driving cost' do
    expect(tiles).to eq(
      [
        ['9,877 km', 'Ø 27 km/day'],
        ['2,092 kWh', 'used'],
        ['373 €', 'cost'],
      ],
    )
  end

  it 'names the cost and the energy in full on the desktop' do
    expect(wide_labels).to eq([I18n.t('sensors.car_driving_energy'), I18n.t('sensors.car_driving_costs')])
  end

  it 'loads the chart of each figure' do
    expect(charts).to eq(%w[car_distance car_driving_energy car_driving_costs])
  end

  # Like a bar of a drive in the timeline of a day
  it 'shows the color of a drive in the swatch before the title' do
    expect(html.xpath('.//h2/preceding-sibling::span/span').pluck('style')).to eq(['flex-grow: 100; background: var(--color-car-drive)'])
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
      expect(html.css('[data-tooltip-target="html"] span.justify-between').size).to eq(2)
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
    consumption, cost = tooltips

    expect(cost).to include(I18n.t('sensors.car_cost_rate'), '3.77 €')
    expect(consumption).to include(I18n.t('sensors.car_consumption_rate'), '21.2 kWh', 'charging losses')
  end

  # A rate needs the charging of the days around a drive
  context 'with a drive without a rate' do
    let(:driving) { Car::Driving::Totals.empty }

    it 'tells what is missing' do
      expect(tiles.drop(1).map(&:first)).to eq(%w[– –])
      expect(tooltips).to all(include('The data is not enough'))
    end
  end

  # A period without a drive says so in the place of the figures, which
  # would be 0 and dashes
  context 'without a drive' do
    let(:distance) { nil }
    let(:driving) { Car::Driving::Totals.empty }

    it 'says so instead of the figures' do
      expect(tiles).to be_empty
      expect(html.css('section > div').last.text.squish).to eq('No drives')
    end

    it 'loads no chart and explains nothing' do
      expect(charts).to be_empty
      expect(tooltips).to be_empty
    end

    it 'has no color in the swatch' do
      expect(html.xpath('.//h2/preceding-sibling::span/span').pluck('style')).to eq(['flex-grow: 100; background: var(--color-fill-strong)'])
    end
  end
end
