describe 'Settings' do
  include ActiveSupport::Testing::TimeHelpers

  before do
    travel_to Time.zone.local(2022, 6, 21, 12, 0, 0)

    Price.create!(
      name: 'electricity',
      starts_at: Date.parse('2020-11-27'),
      value: 0.2545,
      note: 'Test electricity price',
    )

    Price.create!(
      name: 'feed_in',
      starts_at: Date.parse('2020-11-27'),
      value: 0.0832,
      note: 'Test feed-in price',
    )
  end

  context 'when no admin user is logged in' do
    it 'shows 403 error when trying to access prices page' do
      visit '/settings/prices'
      expect(page).to have_content('ForbiddenError')
    end
  end

  context 'when admin user is logged in' do
    before do
      login_as_admin
      visit '/settings/prices'
    end

    it 'can list prices' do
      expect(page).to have_current_path('/settings/prices/electricity')

      within '#list' do
        expect(page).to have_content('27.11.2020')
        expect(page).to have_content('0,2545 €')
      end

      click_on 'Einspeisung'
      expect(page).to have_current_path('/settings/prices/feed_in')
      within '#list' do
        expect(page).to have_content('27.11.2020')
        expect(page).to have_content('0,0832 €')
      end
    end

    it 'can see buttons for add/edit, but not delete' do
      expect(page).to have_css('button[aria-label="Neu"]')
      expect(page).to have_css('button[aria-label="Bearbeiten"]')
      expect(page).to have_no_css('button[aria-label="Löschen"]')
    end

    it 'can create and delete a price' do
      find('button[aria-label="Neu"]').click

      # Save without filling out the form
      within '#form_price' do
        click_on 'Speichern'
      end
      expect(page).to have_content('muss ausgefüllt werden')

      # Fill out the form, save and check if the price is listed
      fill_in 'price_starts_at', with: '2023-01-01'
      fill_in 'price_value', with: '0.1234'
      fill_in 'price_note', with: 'Das ist ein Test'
      within '#form_price' do
        click_on 'Speichern'
      end
      within '#list' do
        expect(page).to have_content('01.01.2023')
        expect(page).to have_content('0,1234 €')
        expect(page).to have_content('Das ist ein Test')
      end

      # Edit the price and try to save with empty price value
      first('button[aria-label="Bearbeiten"]').click
      fill_in 'price_value', with: ''
      click_on 'Speichern'
      expect(page).to have_content('muss ausgefüllt werden')

      # Change the price value and check if the price is updated
      fill_in 'price_value', with: '0.5678'
      click_on 'Speichern'
      within '#list' do
        expect(page).to have_content('0,5678 €')
      end

      # Delete the price and check if the price is not listed anymore
      accept_confirm { first('button[aria-label="Löschen"]').click }
      within '#list' do
        expect(page).to have_no_content('01.01.2023')
      end
    end
  end
end
