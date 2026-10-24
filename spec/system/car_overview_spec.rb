describe 'Car overview (mobile)' do
  let(:day) { Date.new(2022, 6, 20) }

  before do
    driven_by :playwright_mobile

    Sensor::Config.setup(ENV.to_h.merge('INFLUX_SENSOR_CAR_ODOMETER_1' => 'Trabant:odometer'))
    allow(Car::Report).to receive(:pending_days).and_return([])

    # A late request of the example before can create the car again after
    # its cleanup (see Car.configured)
    Car.find_or_initialize_by(id: 1).update!(name: 'Trabant')
    Summary.find_or_create_by!(date: day)
    SummaryValue.create!(date: day, field: :car_odometer_1, aggregation: :sum, value: 150)
    start = day.in_time_zone.change(hour: 12)
    ChargingSession.create!(kind: :wallbox, origin: :detection, car_id: 1, started_at: start, ended_at: start + 1.hour, kwh: 30, kwh_grid: 10, cost: 5)
  end

  # A system spec runs without a transaction. The summaries come from the seed.
  after do
    ChargingSession.delete_all
    SummaryValue.where(field: :car_odometer_1).delete_all
    Car.delete_all
    Sensor::Config.setup(ENV)
  end

  # The first chart of the column that a phone shows
  def active_column = find('[data-car-overview-target=column][data-active=true]', visible: :all)['data-car-overview-charts'].split.first

  def chart(sensor_name) = find("turbo-frame[src*='/cars/charts/#{sensor_name}/']", visible: :all)

  # The tile of a phone that loads the chart of the sensor, the first one where
  # two load it, like the charged energy before the share of PV
  def tile(sensor_name) = first("div.lg\\:hidden.grid a[data-stats-with-chart--component-sensor-name-param='#{sensor_name}']")

  it 'shows the chart of the column of a tapped tile' do
    visit "/cars/car_distance/#{day}"
    expect(tile('car_distance')).to be_visible
    expect(active_column).to eq('car_distance')

    tile('car_charging').click

    expect(page).to have_current_path("/cars/car_charging/#{day}")
    expect(active_column).to eq('car_charging')
    expect(chart('car_charging')).to be_visible
    expect(chart('car_distance')).not_to be_visible
  end

  # Only the chart of the address renders the navigation, and the address
  # comes as the referer of the chart. So a tap must change the address
  # before its chart loads (see Cars::FrameNavigation).
  it 'keeps the chart of the tap in the navigation' do
    visit "/cars/car_distance/#{day}"
    expect(tile('car_distance')).to be_visible
    expect(page).to have_css("a[href='/cars/car_distance/#{day - 1}']", visible: :all)

    tile('car_charging').click

    expect(page).to have_css("a[href='/cars/car_charging/#{day - 1}']", visible: :all)
    expect(page).to have_no_css("a[href='/cars/car_distance/#{day - 1}']", visible: :all)
  end

  # The menu of a chart offers the charts of both columns
  it 'shows the column of a chart from the menu' do
    visit "/cars/car_distance/#{day}"
    expect(active_column).to eq('car_distance')

    find('select[name="sensor-selector"] option[value*="/car_charging/"]', visible: :all).select_option

    expect(active_column).to eq('car_charging')
    expect(chart('car_charging')).to be_visible
  end
end
