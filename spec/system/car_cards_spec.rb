describe 'Car cards (mobile)' do
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

  def pressed_card = find('[data-car-cards-target=button][aria-pressed=true]')

  # The main value of each card
  def charged = find('a[data-car-card=charging]', visible: :all)
  def distance = find('a[data-car-card=driving]', visible: :all)

  it 'loads the chart of the card that a tap shows' do
    visit "/cars/car_distance/#{day}"
    expect(pressed_card).to have_text('Fahren')
    expect(charged).not_to be_visible

    click_on 'Laden'

    expect(pressed_card).to have_text('Laden')
    expect(charged).to be_visible
    expect(distance).not_to be_visible
    expect(page).to have_current_path("/cars/car_charging/#{day}")
    expect(page).to have_css("turbo-frame[src$='/cars/charts/car_charging/#{day}']")
  end

  # A link can open the chart of the other card, for example from the
  # wallbox of the start page
  it 'shows the card of the chart' do
    visit "/cars/car_charging/#{day}"

    expect(pressed_card).to have_text('Laden')
  end

  it 'shows the card of a chart from the menu' do
    visit "/cars/car_distance/#{day}"
    expect(pressed_card).to have_text('Fahren')

    find('select[name="sensor-selector"] option[value*="/car_charging/"]').select_option

    expect(pressed_card).to have_text('Laden')
    expect(charged).to be_visible
  end
end
