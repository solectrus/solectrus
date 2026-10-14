describe 'Settings Places' do
  let(:place) { Place.create!(latitude: 50.92263, longitude: 6.40706) }

  before do
    stub_request(:get, %r{\Ahttps://nominatim\.openstreetmap\.org/reverse}).to_return(body: { name: '', address: { town: 'Jülich' } }.to_json)
  end

  describe 'GET /settings/places' do
    before do
      Sensor::Config.setup(
        ENV.to_h.merge(
          'INFLUX_SENSOR_CAR_LATITUDE_1' => 'Trabant:latitude',
          'INFLUX_SENSOR_CAR_LONGITUDE_1' => 'Trabant:longitude',
        ),
      )
      # No day waits for the visits, unless a spec says so
      allow(Summary).to receive(:missing_or_stale_days_for).and_return([])
    end

    after { Sensor::Config.setup(ENV) }

    it 'forbids the list to a guest' do
      get settings_places_path

      expect(response).to have_http_status(:forbidden)
    end

    it 'builds the days that wait for the visits first' do
      allow(Summary).to receive(:missing_or_stale_days_for).and_return([Date.current])
      login_as_admin
      get settings_places_path

      expect(response.body).to include('sequential-frames')
    end

    it 'lists the places with their time, without a request to Nominatim' do
      place.update!(name: 'Home')
      start = Date.yesterday.beginning_of_day
      place.visits.create!(date: start.to_date, car: Car.configured.first, started_at: start, ended_at: start + 2.hours)
      login_as_admin
      get settings_places_path

      expect(response).to have_http_status(:ok)
      expect(response.body).to include('Home', '2 h')
      expect(response.body).to include(settings_cars_path, I18n.t('settings.cars.vehicles'))
      # The time links to the visits of the place
      expect(response.body).to include(%(href="#{cars_visits_path(place: place.id)}"))
      expect(a_request(:get, /nominatim/)).not_to have_been_made
    end

    it 'loads the next page into its frame' do
      26.times { Place.create!(latitude: (it / 100.0) + 50, longitude: 6.4) }
      login_as_admin
      get settings_places_path

      expect(response.body).to include('id="places_page_2"')

      get settings_places_path(page: 2), headers: { 'Turbo-Frame' => 'places_page_2' }

      expect(response.body).to include('<turbo-frame', 'id="places_page_2"')
      expect(response.body).not_to include('places_page_3')
    end

    context 'without a sponsorship' do
      before { allow(ApplicationPolicy.instance).to receive(:feature_enabled?).and_return(false) }

      it 'keeps the tab and shows the upsell in place of the places' do
        place.update!(name: 'Home')
        login_as_admin
        get settings_places_path

        expect(response).to have_http_status(:ok)
        expect(response.body).to include('Exclusively for sponsors', %(href="#{settings_places_path}"))
        expect(response.body).not_to include('Home')
      end

      it 'answers no form' do
        login_as_admin
        get edit_settings_place_path(place)

        expect(response).to have_http_status(:not_found)
      end
    end
  end

  describe 'GET /settings/places/:id/edit' do
    it 'forbids the form to a guest' do
      get edit_settings_place_path(place)

      expect(response).to have_http_status(:forbidden)
    end

    it 'shows the address as the title' do
      login_as_admin
      get edit_settings_place_path(place), headers: { 'Turbo-Frame' => 'modal' }

      expect(response.body).to include('id="modal-sheet-title">Jülich</h1>')
      expect(response.body).not_to include('placeholder=')
      expect(response.body).to include('id="place_home"', I18n.t('places.labels.home'))
    end

    it 'offers home with a switch while no other place is home' do
      Place.create!(latitude: 50.906, longitude: 6.407, name: 'Old', labels: ['home'])
      place.update!(labels: ['home'])
      login_as_admin
      get edit_settings_place_path(place), headers: { 'Turbo-Frame' => 'modal' }

      expect(response.body).to include('id="place_home"')
      expect(response.body).not_to include(I18n.t('settings.places.make_home'))
    end

    it 'moves home here only with an action that asks first, while another place is home' do
      Place.create!(latitude: 50.906, longitude: 6.407, name: 'Old', labels: ['home'])
      login_as_admin
      get edit_settings_place_path(place), headers: { 'Turbo-Frame' => 'modal' }

      expect(response.body).not_to include('id="place_home"')
      expect(response.body).to include(I18n.t('settings.places.make_home'), CGI.escapeHTML(I18n.t('settings.places.make_home_confirm', previous: 'Old')))
      expect(response.body).to include('name="place[home]" value="1"')
    end

    it 'gives the row of the list the town of the new address' do
      login_as_admin
      get edit_settings_place_path(place), headers: { 'Turbo-Frame' => 'modal' }

      expect(response.body).to include(%(<turbo-stream action="replace" target="place_#{place.id}">))

      get edit_settings_place_path(place), headers: { 'Turbo-Frame' => 'modal' }

      expect(response.body).not_to include('<turbo-stream')
    end

    it 'drops the snapshot of the list on the page of a phone' do
      login_as_admin
      get edit_settings_place_path(place)

      expect(response.body).to include('<turbo-stream action="clear_cache">')
    end

    context 'with visits' do
      before do
        car = Car.create!(id: 1)
        [Time.zone.parse('2026-08-10 10:00'), Time.zone.parse('2026-09-10 10:00')].each do |started_at|
          place.visits.create!(car:, date: started_at.to_date, started_at:, ended_at: started_at + 1.hour)
        end
        login_as_admin
      end

      it 'leads to the visits of the place on the page of a phone, and counts them' do
        get edit_settings_place_path(place)

        expect(response.body).to include(%(href="#{settings_places_path}"), %(href="/cars/places/#{place.id}/visits"))
        expect(response.body).to include(I18n.t('visits.at_place', count: 2))
      end

      it 'leads back to the list of the visits that opened it, and keeps its car and timeframe' do
        get edit_settings_place_path(place, return_to: '/cars/1/visits/2026-09')

        expect(response.body).to include('href="/cars/1/visits/2026-09"', %(href="/cars/1/places/#{place.id}/visits/2026-09"))
        expect(response.parsed_body.at_css("#form_place_#{place.id} input[name=return_to]")['value']).to eq('/cars/1/visits/2026-09')
        expect(response.body).to include(I18n.t('visits.at_place', count: 1))
      end

      it 'counts the visits of the whole time for a list with an invalid timeframe' do
        get edit_settings_place_path(place, return_to: '/cars/visits/2026-09-30..2026-09-01')

        expect(response).to have_http_status(:ok)
        expect(response.body).to include(I18n.t('visits.at_place', count: 2))
      end
    end

    it 'does not lead to the visits of a place without one' do
      login_as_admin
      get edit_settings_place_path(place)

      expect(response.body).not_to include(%(href="/cars/places/#{place.id}/visits"))
    end

    it 'does not lead to the visits from the list of the visits of the place' do
      login_as_admin
      get edit_settings_place_path(place, return_to: "/cars/places/#{place.id}/visits")

      expect(response.body).not_to include(I18n.t('visits.filter_place'))
    end

    it 'ignores a return_to to another host' do
      login_as_admin
      get edit_settings_place_path(place, return_to: 'https://example.com/cars/visits')

      expect(response.body).not_to include('example.com')
    end

    it 'ignores a return_to with a scheme and a port, also on this host' do
      login_as_admin
      get edit_settings_place_path(place, return_to: "http://#{host}:9999/cars/visits")

      expect(response.body).not_to include(':9999')
    end
  end

  describe 'PATCH /settings/places/:id' do
    it 'gives the place a name of its own and replaces its row in the modal' do
      login_as_admin
      patch settings_place_path(place), params: { place: { name: 'Home' } }, headers: { 'Turbo-Frame' => 'modal' }, as: :turbo_stream

      expect(place.reload.name).to eq('Home')
      expect(response.body).to include(%(target="place_#{place.id}"), 'Home')
      # The places of the list of the visits
      expect(response.body).to include(%(targets="[data-visit-place-labels=&#39;#{place.id}&#39;]"), %(targets="[data-visit-place-name=&#39;#{place.id}&#39;]"), %(targets="[data-visit-place-locality=&#39;#{place.id}&#39;]"))
    end

    it 'moves home to the place, and replaces the row of the old home' do
      old_home = Place.create!(latitude: 50.906, longitude: 6.407, name: 'Old', labels: ['home'])
      login_as_admin
      patch settings_place_path(place), params: { place: { home: '1' } }, headers: { 'Turbo-Frame' => 'modal' }, as: :turbo_stream

      expect(Place.home).to eq(place)
      expect(response.body).to include(%(target="place_#{place.id}"), %(target="place_#{old_home.id}"))
      expect(response.body).to include(CGI.escapeHTML(I18n.t('settings.places.home_moved', previous: 'Old')))
    end

    it 'goes back to the list from the page of a phone' do
      login_as_admin
      patch settings_place_path(place), params: { place: { name: 'Home' } }, as: :turbo_stream

      expect(place.reload.name).to eq('Home')
      expect(response.body).to include(%(<turbo-stream action="back_to" target="#{settings_places_path}">))
    end

    it 'goes back to the list of the visits that opened the form' do
      login_as_admin
      patch settings_place_path(place, return_to: '/cars/visits/2026-09'), params: { place: { name: 'Home' } }, as: :turbo_stream

      expect(response.body).to include('<turbo-stream action="back_to" target="/cars/visits/2026-09">')
    end
  end
end
