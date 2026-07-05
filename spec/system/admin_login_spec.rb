describe 'Administrator login' do
  include ActiveSupport::Testing::TimeHelpers

  context 'when not logged in' do
    before do
      visit '/'
      page.execute_script(
        "document.querySelector('a[href=\"/login\"]').click()",
      )
    end

    it 'has login form' do
      expect(page).to have_css('#new_admin_user')
      expect(page).to have_field('admin_user_password')
      expect(page).to have_button('Anmelden')
    end

    it 'cannot login with invalid password' do
      fill_in 'admin_user_password', with: 'wrong'
      click_on 'Anmelden'

      expect(page).to have_css('#new_admin_user')
      expect(page).to have_text('ist nicht gültig')
      expect(page).to have_current_path('/login')
    end

    it 'can cancel back to the homepage without logging in' do
      click_on 'Abbrechen'

      expect(page).to have_no_css('#new_admin_user')
      expect(page).to have_link(href: '/login', visible: :all)
      expect(page).to have_no_link(href: '/logout', visible: :all)
    end

    it 'can login with valid password' do
      fill_in 'admin_user_password', with: 'secret'
      click_on 'Anmelden'

      expect(page).to have_no_link(href: '/login', visible: :all)
      expect(page).to have_link(href: %r{/logout}, visible: :all)
    end
  end

  context 'when coming from a specific page' do
    before do
      visit '/forecast'
      page.execute_script(
        "document.querySelector('a[href=\"/login\"]').click()",
      )
    end

    it 'returns to that page after a successful login' do
      fill_in 'admin_user_password', with: 'secret'
      click_on 'Anmelden'

      expect(page).to have_current_path('/forecast')
      expect(page).to have_link(href: %r{/logout}, visible: :all)
    end

    it 'returns to that page when cancelling' do
      click_on 'Abbrechen'

      expect(page).to have_current_path('/forecast')
      expect(page).to have_link(href: '/login', visible: :all)
    end
  end

  context 'when logged in' do
    before do
      login_as_admin
      visit '/'
    end

    it 'can logout' do
      page.execute_script(
        "document.querySelector('a[href^=\"/logout\"]').click()",
      )

      expect(page).to have_link(href: '/login', visible: :all)
      expect(page).to have_no_link(href: %r{/logout}, visible: :all)
    end

    it 'returns to the current page when logging out from a public page' do
      visit '/forecast'
      page.execute_script(
        "document.querySelector('a[href^=\"/logout\"]').click()",
      )

      expect(page).to have_current_path('/forecast')
      expect(page).to have_link(href: '/login', visible: :all)
    end

    it 'returns to the homepage when logging out from an admin-only page' do
      visit '/settings/general'
      page.execute_script(
        "document.querySelector('a[href^=\"/logout\"]').click()",
      )

      expect(page).to have_current_path('/power_balance/now')
      expect(page).to have_link(href: '/login', visible: :all)
    end
  end
end
