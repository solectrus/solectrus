describe 'Charging sessions' do
  let(:car) { Car.configured.first }

  def offsite(started_at, note)
    ChargingSession.create!(kind: :offsite, origin: :user, car:, started_at:, kwh: 20, cost: 10, note:)
  end

  def row_button(label, text)
    find('#list .group', text:).find("button[aria-label='#{label}']")
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

      row_button('Bearbeiten', 'June trip').click
      within '#modal' do
        fill_in 'charging_session_note', with: 'June trip, edited'
        click_on 'Speichern'
      end

      expect(page).to have_text('Gespeichert')
      expect(page).to have_text('June trip, edited')
      expect(page).to have_no_text('March trip')
    end

    it 'deletes a session and keeps the timeframe of the list' do
      visit '/cars/charging_sessions/offsite/2022-06'

      accept_confirm { row_button('Löschen', 'June trip').click }

      expect(page).to have_text('Keine Auswärtsladungen')
      expect(page).to have_no_text('March trip')
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

      find_by_id('list').find("button[aria-label='Bearbeiten']").click
      within '#modal' do
        select 'Gast', from: 'charging_session_car_id'
        click_on 'Speichern'
      end

      expect(page).to have_text('Keine Ladevorgänge an der Wallbox')
      expect(ChargingSession.wallbox.sole).to have_attributes(guest: true, car_id: nil)
    end
  end
end
