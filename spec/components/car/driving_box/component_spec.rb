describe Car::DrivingBox::Component, type: :component do
  subject(:html) { render_inline(described_class.new(report:)) }

  # The label and the value of each tile of a phone
  def tiles = html.css('div.lg\:hidden.grid > *').map { |tile| tile.css('> span').first(2).map { it.text.squish } }

  # The charts that a click on a figure loads
  def charts = html.css('[data-stats-with-chart--component-sensor-name-param]').pluck('data-stats-with-chart--component-sensor-name-param').uniq

  # The text of each tooltip of the desktop figures
  def tooltips = html.css('.max-lg\:hidden [data-tooltip-target="html"]').map { it.text.squish }

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
        [I18n.t('sensors.car_distance_short'), '9,877 km'],
        [I18n.t('car_breakdown.cost_rate_short'), '3.77 €'],
        [I18n.t('car_breakdown.consumption_rate_short'), '21.2 kWh'],
      ],
    )
    expect(html.text).to include(I18n.t('car_breakdown.per_day_note', distance: '27 km'))
  end

  it 'loads the chart of each figure' do
    expect(charts).to eq(%w[car_distance car_cost_rate car_consumption_rate])
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
      expect(tiles.drop(1).map(&:last)).to eq(%w[– –])
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
          [I18n.t('sensors.car_distance_short'), '0 km'],
          [I18n.t('car_breakdown.cost_rate_short'), '–'],
          [I18n.t('car_breakdown.consumption_rate_short'), '–'],
        ],
      )
    end

    it 'loads the empty charts, but explains nothing' do
      expect(charts).to eq(%w[car_distance car_cost_rate car_consumption_rate])
      expect(tooltips).to be_empty
    end
  end
end
