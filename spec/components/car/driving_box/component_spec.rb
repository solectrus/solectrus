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

  # The numbers at the ends of each bar of a span
  def span_ends = html.css('span.justify-between').map { it.css('span').map(&:text) }

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

  it 'shows the distance with its average of a day, and the two rates' do
    expect(tiles).to eq(
      [
        ['9,877 km', 'Ø 27 km/day'],
        ['3.77 €', 'per 100 km'],
        ['21.2 kWh', 'per 100 km'],
      ],
    )
  end

  it 'names the rates in full on the desktop' do
    expect(wide_labels).to eq([I18n.t('car_breakdown.cost_rate'), I18n.t('car_breakdown.consumption_rate')])
  end

  it 'loads the chart of each figure' do
    expect(charts).to eq(%w[car_distance car_cost_rate car_consumption_rate])
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
    let(:span) { ->(min, max) { Car::Spans::Span.new(min:, max:, min_timeframe: nil, max_timeframe: nil) } }

    before do
      allow(report).to receive(:spans).and_return(instance_double(Car::Spans, cost_per_100km: span.call(1.06, 10.67), consumption_per_100km: span.call(9.31, 38.92)))
    end

    it 'shows the ends of each span, the good end on the right' do
      expect(span_ends).to eq([%w[10.67 1.06], %w[38.9 9.3]])
    end
  end

  # A day has the timeline of the day in place of the charts
  context 'with a day' do
    before { allow(report).to receive(:timeframe).and_return(Timeframe.new('2025-06-20')) }

    it 'loads no chart' do
      expect(charts).to be_empty
    end
  end

  # Each rate has the amount that it divides by the distance, and what only
  # this rate means
  it 'explains each rate in its own tooltip' do
    cost, consumption = tooltips

    expect(cost).to include(I18n.t('sensors.car_driving_costs'), '373 €')
    expect(consumption).to include('2,092 kWh', 'charging losses')
  end

  # A rate needs the charging of the days around a drive
  context 'with a drive without a rate' do
    let(:driving) { Car::Driving::Totals.empty }

    it 'tells what is missing' do
      expect(tiles.drop(1).map(&:first)).to eq(%w[– –])
      expect(tooltips).to all(include('The data is not enough'))
    end
  end

  # A period without a drive keeps its tiles, which load no chart and
  # explain nothing
  context 'without a drive' do
    let(:distance) { nil }
    let(:driving) { Car::Driving::Totals.empty }

    it 'shows 0 and dashes in the same tiles' do
      expect(tiles).to eq(
        [
          ['0 km', 'driven'],
          ['–', 'per 100 km'],
          ['–', 'per 100 km'],
        ],
      )
    end

    it 'loads the empty charts, but explains nothing' do
      expect(charts).to eq(%w[car_distance car_cost_rate car_consumption_rate])
      expect(tooltips).to be_empty
    end

    it 'has no color in the swatch' do
      expect(html.xpath('.//h2/preceding-sibling::span/span').pluck('style')).to eq(['flex-grow: 100; background: var(--color-fill-strong)'])
    end
  end
end
