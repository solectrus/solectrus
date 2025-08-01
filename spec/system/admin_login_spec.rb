describe 'Administrator login' do
  include ActiveSupport::Testing::TimeHelpers

  before { travel_to Time.zone.local(2022, 6, 21, 12, 0, 0) }

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
      expect(page).to have_content('ist nicht gültig')
      expect(page).to have_link(href: '/login')
      expect(page).to have_no_link(href: '/logout')
    end

    it 'can login with valid password' do
      fill_in 'admin_user_password', with: 'secret'
      click_on 'Anmelden'

      expect(page).to have_no_link(href: '/login')
      expect(page).to have_link(href: '/logout')
    end
  end

  context 'when logged in' do
    before do
      login_as_admin
      visit '/'
    end

    it 'can logout' do
      page.execute_script(
        "document.querySelector('a[href=\"/logout\"]').click()",
      )

      expect(page).to have_link(href: '/login')
      expect(page).to have_no_link(href: '/logout')
    end
  end
end
