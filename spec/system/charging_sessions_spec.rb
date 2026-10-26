describe 'Charging sessions' do
  let(:car) { Car.configured.first }

  def offsite(started_at, note)
    ChargingSession.create!(kind: :offsite, origin: :user, car:, started_at:, kwh: 20, cost: 10, note:)
  end

  def row(text)
    find('#list [data-controller="ui--table-row--component"]', text:)
  end

  before do
    login_as_admin
    # The page of the charging builds the days of its windows first
    allow(Car::Report).to receive(:pending_days).and_return([])
  end

  # System tests are not transactional
  after { ChargingSession.delete_all }

  # The bar of an offsite session in the timeline of a day opens its form
  context 'with the timeline of a day' do
    let!(:session) { offsite(Time.zone.local(2022, 6, 10, 18), 'June trip') }

    it 'edits the session in the modal and renders the day again' do
      visit "/cars/#{car.id}/2022-06-10"
      find("a[href^='/cars/charging_sessions/#{session.id}/edit']", visible: :visible).click

      within '#modal' do
        fill_in 'charging_session_kwh', with: '33'
        click_on 'Speichern'
      end

      expect(page).to have_no_css('#modal dialog')
      expect(page).to have_css("a[href^='/cars/charging_sessions/#{session.id}/edit'][aria-label*='33,0 kWh']", visible: :all)
    end
  end

  context 'with a list of a timeframe' do
    before do
      offsite(Time.zone.local(2022, 6, 10, 18), 'June trip')
      offsite(Time.zone.local(2021, 3, 1, 18), 'March trip')
    end

    it 'edits a session and keeps the timeframe of the list' do
      visit '/cars/charging_sessions/offsite/2022-06'
      expect(page).to have_text('June trip')
      expect(page).to have_no_text('March trip')

      row('June trip').click
      within '#modal' do
        fill_in 'charging_session_note', with: 'June trip, edited'
        click_on 'Speichern'
      end

      expect(page).to have_text('Gespeichert')
      expect(page).to have_text('June trip, edited')
      expect(page).to have_no_text('March trip')
    end

    # The time fields render seconds, which the browser drops from the value
    it 'closes the modal without changes at once' do
      visit '/cars/charging_sessions/offsite/2022-06'

      row('June trip').click
      within('#modal') { click_on 'Schließen' }

      expect(page).to have_no_css('#modal dialog')
      expect(page.document).to have_no_css('#confirm-dialog[open]')
    end

    it 'deletes a session from its form and keeps the timeframe of the list' do
      visit '/cars/charging_sessions/offsite/2022-06'

      row('June trip').click
      within('#modal') { accept_confirm_dialog { click_on 'Löschen' } }

      expect(page).to have_text('Keine Auswärtsladungen')
      expect(page).to have_no_text('March trip')
    end

    # The map sends the event, so the spec needs no tiles
    it 'discards a moved point' do
      visit '/cars/charging_sessions/offsite/2022-06'

      row('June trip').click
      within('#modal') do
        find_by_id('charging_session_map')
        page.execute_script(<<~JS)
          document.querySelector('#charging_session_map').dispatchEvent(
            new CustomEvent('car--map--component:moved', { detail: { latitude: 50.1, longitude: 8.1 } })
          )
        JS
        expect(page).to have_button('Speichern', disabled: false)

        click_on 'Änderungen verwerfen'

        # The save button hides while it is disabled
        expect(page).to have_button('Speichern', disabled: true, visible: :hidden)
        expect(find_field('charging_session_latitude', type: :hidden).value).to eq('')
      end
    end

    it 'discards a checked address with its map' do
      found_place = Place.new(latitude: 51.0, longitude: 7.0, geocoding: { 'address' => { 'country_code' => 'de', 'postcode' => '12345', 'town' => 'Town', 'road' => 'Main Street' } })
      allow(Place).to receive(:search).and_return(found_place)
      visit '/cars/charging_sessions/offsite/2022-06'

      row('June trip').click
      within('#modal') do
        fill_in 'charging_session_address', with: 'main street 1, town'
        find_field('charging_session_note').click
        expect(page).to have_field('charging_session_address', with: 'DE-12345 Town, Main Street 1')

        click_on 'Änderungen verwerfen'

        expect(page).to have_field('charging_session_address', with: '')
        expect(page).to have_text('Die Karte zeigt den Ort, sobald die Adresse gefunden ist.')
        expect(page).to have_button('Speichern', disabled: true, visible: :hidden)
        expect(find_field('charging_session_latitude', type: :hidden).value).to eq('')
      end
    end

    # The check replaces the field, whose rendered value is then the checked
    # address
    it 'asks before it closes with a checked address' do
      found_place = Place.new(latitude: 51.0, longitude: 7.0, geocoding: { 'address' => { 'country_code' => 'de', 'postcode' => '12345', 'town' => 'Town', 'road' => 'Main Street' } })
      allow(Place).to receive(:search).and_return(found_place)
      visit '/cars/charging_sessions/offsite/2022-06'

      row('June trip').click
      within('#modal') do
        fill_in 'charging_session_address', with: 'main street 1, town'
        find_field('charging_session_note').click
        expect(page).to have_field('charging_session_address', with: 'DE-12345 Town, Main Street 1')

        click_on 'Schließen'
      end

      expect(page.document).to have_css('#confirm-dialog[open]', text: 'Änderungen verwerfen?')
    end

    # The form opens without Nominatim and asks it once it is shown
    it 'offers the address at the position of the car once the form opened' do
      ChargingSession.find_by(note: 'June trip').update_columns(latitude: 50.0, longitude: 8.0) # rubocop:disable Rails/SkipsModelValidations
      allow(Place).to receive(:address_at).with(50.0, 8.0).and_return('DE-12345 Town, Main Street 1')
      visit '/cars/charging_sessions/offsite/2022-06'

      row('June trip').click

      within('#modal') do
        expect(page).to have_field('charging_session_address', with: 'DE-12345 Town, Main Street 1')
        # The offered address is a change, so the form saves it
        expect(page).to have_button('Speichern', disabled: false)
      end
    end
  end

  context 'with a phone' do
    before do
      driven_by :playwright_mobile
      login_as_admin
      offsite(Time.zone.local(2022, 6, 10, 18), 'June trip')
    end

    it 'edits a session on a page of its own and returns to the list' do
      visit '/cars/charging_sessions/offsite/2022-06'
      row('June trip').click

      expect(page).to have_css('.ui-title-bar h1', text: 'Ladevorgang bearbeiten')
      expect(page).to have_no_css('#modal form')

      fill_in 'charging_session_note', with: 'June trip, edited'
      click_on 'Speichern'

      expect(page).to have_current_path('/cars/charging_sessions/offsite/2022-06')
      expect(page).to have_text('Gespeichert')
      expect(page).to have_text('June trip, edited')
    end

    it 'asks before the back button leaves unsaved changes' do
      visit '/cars/charging_sessions/offsite/2022-06'
      row('June trip').click
      fill_in 'charging_session_note', with: 'June trip, edited'

      message = dismiss_confirm_dialog { find('.ui-title-bar-back').click }
      expect(message).to eq('Änderungen verwerfen?')
      expect(page).to have_field('charging_session_note', with: 'June trip, edited')

      accept_confirm_dialog { find('.ui-title-bar-back').click }
      expect(page).to have_current_path('/cars/charging_sessions/offsite/2022-06')
      expect(page).to have_text('June trip')
      expect(ChargingSession.sole.note).to eq('June trip')
    end

    it 'dismisses a proposal with unsaved changes without a second question' do
      # The detection writes with an upsert, which skips the mark of a save
      ChargingSession.insert!({ kind: 'offsite', origin: 'detection', car_id: car.id, started_at: Time.zone.local(2022, 6, 12, 9), kwh: 15 }) # rubocop:disable Rails/SkipsModelValidations
      proposal = ChargingSession.proposals.sole
      visit "/cars/charging_sessions/#{proposal.id}/edit"
      fill_in 'charging_session_note', with: 'Unsaved'

      message = accept_confirm_dialog { click_on 'Verwerfen' }
      expect(message).to eq('Diese Ladung verwerfen?')

      expect(page).to have_no_current_path(%r{/edit})
      expect(page.document).to have_no_css('#confirm-dialog[open]')
      expect(proposal.reload).to be_dismissed
    end

    # A tap on a spot leaves the list while the map is open. The map visits
    # like the script here, so the spec needs no tiles.
    it 'returns from a spot of the map to the list without the map' do
      visit '/cars/charging_sessions/offsite/2022-06'
      find('a[data-turbo-frame="car_map"]').click
      expect(page).to have_css('#car_map dialog[open]')

      session = ChargingSession.sole
      page.execute_script("Turbo.visit('/cars/charging_sessions/#{session.id}/edit?return_to=%2Fcars%2Fcharging_sessions%2Foffsite%2F2022-06')")
      expect(page).to have_css('.ui-title-bar h1', text: 'Ladevorgang bearbeiten')

      find('.ui-title-bar-back').click
      expect(page).to have_current_path('/cars/charging_sessions/offsite/2022-06')
      expect(page).to have_text('June trip')
      expect(page.document).to have_no_css('#car_map dialog')
    end

    # The save goes back to the entry of the list in the history, so the next
    # way back leaves the list
    it 'returns to the list as its address shows it' do
      visit '/cars/charging_sessions/offsite/2022'
      page.execute_script("Turbo.visit('/cars/charging_sessions/offsite/all')")
      row('June trip').click

      fill_in 'charging_session_note', with: 'June trip, edited'
      click_on 'Speichern'

      expect(page).to have_current_path('/cars/charging_sessions/offsite/all')
      expect(page).to have_text('June trip, edited')

      page.go_back
      expect(page).to have_current_path('/cars/charging_sessions/offsite/2022')
    end
  end

  context 'with a wallbox session that is not assigned' do
    before do
      ChargingSession.create!(
        kind: :wallbox,
        origin: :detection,
        started_at: Time.zone.local(2022, 6, 10, 18),
        ended_at: Time.zone.local(2022, 6, 10, 19),
        kwh: 7,
      )
    end

    # The overview names the session, and its hint leads to the list
    it 'marks it as a guest charge, which then counts' do
      visit '/cars/2022-06'
      click_on '1 Ladung nicht zugeordnet'

      find('#list [data-controller="ui--table-row--component"]').click
      within '#modal' do
        select 'Gast', from: 'charging_session_car_id'
        click_on 'Speichern'
      end
      expect(page).to have_text('Gespeichert')

      visit '/cars/2022-06'
      expect(page).to have_text('Ladekosten')
      expect(page).to have_no_text('nicht zugeordnet')
      expect(ChargingSession.wallbox.sole).to have_attributes(guest: true, car_id: nil)
    end
  end
end
