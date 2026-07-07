describe 'Cash flow settings' do
  after { CashFlow.delete_all }

  context 'when admin user is logged in' do
    before { login_as_admin }

    it 'creates an entry via modal' do
      visit '/settings/cash_flows'

      expect(page).to have_text('Noch keine Einträge vorhanden.')

      click_button title: 'Neu'

      within '#modal' do
        fill_in 'cash_flow_date', with: '2023-08-01'
        fill_in 'cash_flow_amount', with: '-5000'
        fill_in 'cash_flow_note', with: 'Wechselrichter'
        click_on 'Speichern'
      end

      expect(page).to have_text('Gespeichert')

      visit '/settings/cash_flows'
      expect(page).to have_text('Wechselrichter')
      expect(page).to have_text('5.000')
    end
  end

  context 'when admin user is logged in with sponsoring' do
    before do
      allow(ApplicationPolicy).to receive(:amortization?).and_return(true)
      login_as_admin
    end

    # System tests are not transactional, so reset the persisted setting
    after { Setting.amortization_public = false }

    it 'toggles public visibility of the amortization' do
      visit '/settings/cash_flows'

      check 'Amortisationsberechnung für alle Benutzer anzeigen'

      expect(page).to have_text('Gespeichert')
      expect(Setting.amortization_public).to be(true)
    end
  end
end
