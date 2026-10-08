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

      expect(response.body).to include('sequential-frames', 'steps=place_visits')
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

      expect(response.body).to include('id="modal-title"').and include('>Jülich</h1>')
      expect(response.body).not_to include('placeholder=')
      expect(response.body).to include('id="place_labels_home"', I18n.t('places.labels.home'))
    end

    it 'gives the row of the list the town of the new address' do
      login_as_admin
      get edit_settings_place_path(place), headers: { 'Turbo-Frame' => 'modal' }

      expect(response.body).to include(%(<turbo-stream action="replace" target="place_#{place.id}">))

      get edit_settings_place_path(place), headers: { 'Turbo-Frame' => 'modal' }

      expect(response.body).not_to include('<turbo-stream')
    end
  end

  describe 'PATCH /settings/places/:id' do
    it 'gives the place a name of its own and replaces its row' do
      login_as_admin
      patch settings_place_path(place), params: { place: { name: 'Home' } }, as: :turbo_stream

      expect(place.reload.name).to eq('Home')
      expect(response.body).to include(%(target="place_#{place.id}"), 'Home')
      # The places of the list of the visits
      expect(response.body).to include(%(targets="[data-visit-place-name=&#39;#{place.id}&#39;]"), %(targets="[data-visit-place-locality=&#39;#{place.id}&#39;]"))
    end

    it 'moves home to the place, and replaces the row of the old home' do
      old_home = Place.create!(latitude: 50.906, longitude: 6.407, name: 'Old', labels: ['home'])
      login_as_admin
      patch settings_place_path(place), params: { place: { name: 'New', labels: ['', 'home'] } }, as: :turbo_stream

      expect(Place.home).to eq(place)
      expect(response.body).to include(%(target="place_#{place.id}"), %(target="place_#{old_home.id}"))
      expect(response.body).to include(CGI.escapeHTML(I18n.t('settings.places.home_moved', previous: 'Old')))
    end
  end
end
