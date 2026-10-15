describe 'Charging sessions' do
  let(:car) { Car.configured.first }

  def offsite(started_at, note)
    ChargingSession.create!(kind: :offsite, origin: :user, car:, started_at:, kwh: 20, cost: 10, note:)
  end

  def row(text)
    find('#list [data-controller="ui--table-row--component"]', text:)
  end

  before { login_as_admin }

  # System tests are not transactional
  after { ChargingSession.delete_all }

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

    # The list has no timeframe in its address. The save goes back to its
    # entry in the history, so the next way back leaves the list.
    it 'returns to the list as its address shows it' do
      visit '/cars/charging_sessions/offsite/2022'
      page.execute_script("Turbo.visit('/cars/charging_sessions/offsite')")
      row('June trip').click

      fill_in 'charging_session_note', with: 'June trip, edited'
      click_on 'Speichern'

      expect(page).to have_current_path('/cars/charging_sessions/offsite')
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

    it 'marks it as a guest charge and keeps the car filter of the list' do
      visit '/cars/unassigned/charging_sessions/wallbox/2022-06'

      find('#list [data-controller="ui--table-row--component"]').click
      within '#modal' do
        select 'Gast', from: 'charging_session_car_id'
        click_on 'Speichern'
      end

      expect(page).to have_text('Keine Ladevorgänge an der Wallbox')
      expect(ChargingSession.wallbox.sole).to have_attributes(guest: true, car_id: nil)
    end
  end
end
