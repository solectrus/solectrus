describe 'Cars Visited places' do
  let(:home) { Place.create!(latitude: 50.92263, longitude: 6.40706, name: 'Home', labels: ['home']) }
  let(:work) { Place.create!(latitude: 50.906, longitude: 6.407) }

  def visit_at(place, from, to)
    started_at = Time.zone.parse(from)
    place.visits.create!(car: Car.configured.first, date: started_at.to_date, started_at:, ended_at: Time.zone.parse(to))
  end

  before do
    Sensor::Config.setup(
      ENV.to_h.merge(
        'INFLUX_SENSOR_CAR_ODOMETER_1' => 'Trabant:odometer',
        'INFLUX_SENSOR_CAR_LATITUDE_1' => 'Trabant:latitude',
        'INFLUX_SENSOR_CAR_LONGITUDE_1' => 'Trabant:longitude',
      ),
    )
    allow(Summary).to receive(:missing_or_stale_days_for).and_return([])
    visit_at(home, '2026-09-21 18:00', '2026-09-22 07:20')
    visit_at(work, '2026-09-22 07:25', '2026-09-22 16:00')
    visit_at(home, '2026-09-22 16:30', '2026-09-22 22:00')
  end

  after { Sensor::Config.setup(ENV) }

  describe 'GET /cars/places' do
    it 'forbids the list to a guest' do
      get cars_visited_places_path(timeframe: '2026-09')

      expect(response).to have_http_status(:forbidden)
    end

    context 'when logged in as admin' do
      before { login_as_admin }

      # A phone opens the list in a sheet over the car page (see SheetPage)
      # The switch has no numbers, and the head of the sheet has the map
      it 'opens the list in the modal frame, not the timeframe select' do
        get cars_visited_places_path(timeframe: '2026-09', sheet: 1), headers: { 'Turbo-Frame' => 'modal' }

        page = response.parsed_body.at_css('turbo-frame#modal turbo-frame#sheet-page')
        expect(page.at_css('header h2').text.squish).to eq('Locations')
        expect(page.at_css('header p').text.squish).to eq('September 2026')
        expect(page.css('nav a').map { it.text.squish }).to eq(%w[Destinations Visits])
        expect(page.at_css('.ui-keep-lit span.text-fg-secondary.tabular-nums')).to be_nil
        expect(page.at_css('header a[data-turbo-frame="car_map"]')).to be_present
      end

      it 'lists the places with their visits, the most visited first' do
        get cars_visited_places_path(timeframe: '2026-09')

        expect(response.parsed_body.at_css('.ui-keep-lit span.tabular-nums').text).to eq('2 places')
        expect(response.body).to include('Home')
        expect(response.parsed_body.at_css('a[aria-label="2 visits"]').text.strip).to eq("2\u202F×")
        expect(response.parsed_body.css('[data-ui--table-row--component-target=link]').map { it.text.strip }).to eq(['Home', work.display_name || 'Unnamed'])
      end

      # The locality follows the name, like in the visits
      it 'names the locality of a place with a name' do
        home.update!(geocoding: { 'address' => { 'suburb' => 'Braunsfeld', 'city' => 'Köln' } })
        get cars_visited_places_path(timeframe: '2026-09')

        expect(response.parsed_body.at_css("[data-visit-place-locality='#{home.id}']").text).to eq(', Braunsfeld, Köln')
      end

      # The row opens the place with its map, like a row of the visits
      it 'opens a place, and its visits by their number' do
        get cars_visited_places_path(timeframe: '2026-09')

        expect(response.body).to include(
          %(href="#{CGI.escapeHTML(edit_settings_place_path(home, return_to: '/cars/places/2026-09'))}"),
          %(href="/cars/places/#{home.id}/visits/2026-09"),
        )
      end

      it 'switches to the visits, and opens the map of the places' do
        get cars_visited_places_path(timeframe: '2026-09')

        expect(response.body).to include('href="/cars/visits/2026-09"', 'href="/cars/places/map/2026-09"')
      end

      it 'has no numbers and no map without a visit' do
        get cars_visited_places_path(timeframe: '2026-08')

        expect(response.body).to include('No destinations')
        expect(response.parsed_body.at_css('.ui-keep-lit span.tabular-nums')).to be_nil
        expect(response.body).not_to include('/map/2026-08"')
      end

      it 'goes back to the car page in the timeframe and with the car' do
        get cars_visited_places_path(car: 1, timeframe: '2026-09')

        expect(response.body).to include('href="/cars/1/2026-09"')
      end

      it 'keeps the list for another timeframe' do
        get cars_visited_places_path(timeframe: '2026-09')

        expect(response.body).to include('href="/cars/places/2026-08"')
      end
    end
  end
end
