describe 'Settings places (mobile)' do
  before do
    driven_by :playwright_mobile

    Sensor::Config.setup(
      ENV.to_h.merge(
        'INFLUX_SENSOR_CAR_LATITUDE_1' => 'Trabant:latitude',
        'INFLUX_SENSOR_CAR_LONGITUDE_1' => 'Trabant:longitude',
      ),
    )
    allow(Summary).to receive(:missing_or_stale_days_for).and_return([])
    stub_request(:get, %r{\Ahttps://nominatim\.openstreetmap\.org/reverse}).to_return(body: { name: '', address: { town: 'Jülich' } }.to_json)

    # One more place than a page holds, so the last one loads into a frame
    26.times { Place.create!(latitude: (it / 100.0) + 50, longitude: 6.4) }
    login_as_admin
  end

  # A system spec runs without a transaction
  after do
    Place.delete_all
    Sensor::Config.setup(ENV)
  end

  # The link leaves the frame of its page as a visit of Turbo. Else the frame
  # loads the form first, misses itself in the response and loads the page in
  # full (see setupStimulus), which drops the marker of the window.
  it 'opens a place of a further page as a visit of Turbo' do
    visit settings_places_path
    scroll_to find_by_id('places_page_2', visible: :all)
    link = find('#places_page_2 a[data-nav-title]')
    path = link[:href]
    page.execute_script('window.visitMarker = true')
    link.click

    expect(page).to have_current_path(path)
    expect(page).to have_css('.ui-title-bar h1', text: 'Ort bearbeiten')
    expect(page.evaluate_script('window.visitMarker')).to be(true)
  end
end
