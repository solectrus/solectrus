describe 'Cash flow settings' do
  after { CashFlow.delete_all }

  context 'when admin user is logged in' do
    before { login_as_admin }

    # System tests are not transactional, so reset the persisted setting
    after { Setting.enable_amortization = true }

    it 'hides the amortization page from the navigation without a reload' do
      visit '/settings/cash_flows'

      expect(page).to have_css("#primary-nav-desktop a[href='/amortization']")

      select 'Für niemanden (Seite ausblenden)', from: 'Amortisationsrechnung anzeigen'

      expect(page).to have_text('Gespeichert')
      expect(page).to have_no_css("#primary-nav-desktop a[href='/amortization']")
      expect(Setting.enable_amortization).to be(false)
    end

    it 'creates an entry via modal' do
      visit '/settings/cash_flows'

      expect(page).to have_text('Noch keine Zahlungen.')

      click_link 'Neue Zahlung'

      within '#modal' do
        fill_in 'cash_flow_date', with: '2023-08-01'
        fill_in 'cash_flow_amount', with: '-5000'
        fill_in 'cash_flow_note', with: 'Wechselrichter'
        click_on 'Speichern'
      end

      expect(page).to have_text('Gespeichert')

      # The list refreshes in place, without reloading the page.
      expect(page).to have_text('Wechselrichter')
      expect(page).to have_text('5.000')
    end

    it 'deletes an entry from the edit form' do
      CashFlow.create!(date: Date.new(2023, 8, 1), amount: -5000, note: 'Wechselrichter')
      visit '/settings/cash_flows'

      expect(page).to have_text('Wechselrichter')
      expect(page).to have_no_button('Löschen')

      click_on '01.08.2023'
      within('#modal') { accept_confirm { click_on 'Löschen' } }

      expect(page).to have_text('Noch keine Zahlungen.')
    end
  end

  context 'when admin user is logged in on a phone' do
    before do
      driven_by :playwright_mobile
      login_as_admin
    end

    # The filter of a row links to one category, and the way back names it as
    # a list of categories. Both are the same list, so the back button goes
    # back in the history.
    it 'goes back to the filtered list in the history' do
      CashFlow.create!(date: Date.new(2023, 8, 1), amount: -5000, note: 'Wechselrichter', category: 'investment')
      visit '/settings/cash_flows?category=investment'

      click_on '01.08.2023'
      expect(page).to have_current_path(%r{/settings/cash_flows/\d+/edit})

      find('.ui-title-bar-back').click
      expect(page).to have_current_path('/settings/cash_flows?category=investment')

      page.go_forward
      expect(page).to have_current_path(%r{/settings/cash_flows/\d+/edit})
    end
  end

  context 'when admin user is logged in with sponsoring' do
    before do
      allow(ApplicationPolicy).to receive(:amortization?).and_return(true)
      login_as_admin
    end

    # System tests are not transactional, so reset the persisted setting
    after { Setting.amortization_public = false }

    it 'shows the amortization calculation to all users' do
      visit '/settings/cash_flows'

      select 'Für alle Nutzer', from: 'Amortisationsrechnung anzeigen'

      expect(page).to have_text('Gespeichert')
      expect(Setting.amortization_public).to be(true)
    end
  end
end
