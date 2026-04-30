describe 'Settings' do
  include ActiveSupport::Testing::TimeHelpers

  let(:installation_date) { Rails.configuration.x.installation_date }

  context 'when no admin user is logged in' do
    it 'shows 403 error when trying to access prices page' do
      visit '/settings/prices'
      expect(page).to have_text('ForbiddenError')
    end
  end

  context 'when admin user is logged in' do
    before do
      login_as_admin
    end

    context 'when visiting general settings' do
      before { visit '/settings/general' }

      it 'has submit button disabled initially' do
        expect(page).to have_button('Speichern', disabled: true)
      end

      it 'enables submit button when form is changed' do
        find_field('setting_plant_name').send_keys('x')
        expect(page).to have_button('Speichern', disabled: false)
      end

      it 'disables submit button when change is reverted' do
        find_field('setting_plant_name').send_keys('x')
        expect(page).to have_button('Speichern', disabled: false)

        find_field('setting_plant_name').send_keys(:backspace)
        expect(page).to have_button('Speichern', disabled: true)
      end
    end

    context 'when visiting prices settings' do
      before { visit '/settings/prices' }

      it 'can list prices' do
        expect(page).to have_current_path('/settings/prices/electricity')

        within '#list' do
          expect(page).to have_text(I18n.l(installation_date, locale: :de))
          expect(page).to have_text('0,2545 €')
        end

        click_on 'Einspeisung'
        expect(page).to have_current_path('/settings/prices/feed_in')
        within '#list' do
          expect(page).to have_text(I18n.l(installation_date, locale: :de))
          expect(page).to have_text('0,0832 €')
        end
      end

      it 'can see buttons for add/edit, but not delete' do
        expect(page).to have_button('Neu')
        expect(page).to have_button('Bearbeiten')
        expect(page).to have_no_button('Löschen')
      end

      it 'can create and delete a price' do
        click_on 'Neu'

        # Fill out the form, save and check if the price is listed
        fill_in 'price_starts_at', with: '2023-01-01'
        fill_in 'price_value', with: '0.1234'
        fill_in 'price_note', with: 'Das ist ein Test'
        within('dialog') { click_on 'Speichern' }
        within '#list' do
          expect(page).to have_text('01.01.2023')
          expect(page).to have_text('0,1234 €')
          expect(page).to have_text('Das ist ein Test')
        end

        # Edit the price and try to save with empty price value
        click_on 'Bearbeiten', match: :first
        fill_in 'price_value', with: ''
        within('dialog') { click_on 'Speichern' }
        expect(page).to have_text('muss ausgefüllt werden')

        # Change the price value and check if the price is updated
        fill_in 'price_value', with: '0.5678'
        within('dialog') { click_on 'Speichern' }
        within '#list' do
          expect(page).to have_text('0,5678 €')
        end

        # Delete the price and check if the price is not listed anymore
        accept_confirm { click_on 'Löschen', match: :first }
        within '#list' do
          expect(page).to have_no_text('01.01.2023')
        end
      end
    end
  end
end
