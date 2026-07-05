describe 'Amortization' do
  # System tests run without transactional fixtures, so clean up manually
  before do
    CashFlow.create!(date: Date.new(2022, 1, 1), amount: -5000, note: 'PV system')
  end

  after { CashFlow.delete_all }

  context 'when not logged in, sponsoring active and made public' do
    before do
      allow(ApplicationPolicy).to receive(:amortization?).and_return(true)
      allow(Setting).to receive(:amortization_public).and_return(true)
    end

    it 'shows the detail view including the parameter sliders' do
      visit '/amortization'

      expect(page).to have_text(/Nominaler Saldo heute/i)
      expect(page).to have_css('canvas')

      # Sliders live in a collapsible drawer, so open it first
      click_button 'Parameter anpassen'
      expect(page).to have_field('amortization[period_years]', type: 'range')
    end
  end

  context 'when not logged in and not made public' do
    before do
      allow(ApplicationPolicy).to receive(:amortization?).and_return(true)
      allow(Setting).to receive(:amortization_public).and_return(false)
    end

    it 'hides the calculation behind an admin-only hint' do
      visit '/amortization'

      expect(page).to have_text('nur für Administratoren')
      expect(page).to have_no_css('canvas')
    end
  end

  context 'when logged in as admin without sponsoring' do
    before do
      allow(ApplicationPolicy).to receive(:amortization?).and_return(false)
      login_as_admin
    end

    it 'shows the sponsor hint instead of details' do
      visit '/amortization'

      expect(page).to have_text('Exklusiv für Sponsoren')
      expect(page).to have_no_css('canvas')
    end
  end

  context 'when logged in as admin with sponsoring' do
    before do
      allow(ApplicationPolicy).to receive(:amortization?).and_return(true)
      login_as_admin
    end

    it 'shows the detail view with stats and chart' do
      visit '/amortization'

      # Rail tile labels are uppercased via CSS, so match case-insensitively
      expect(page).to have_text(/Amortisationsgrad/i)
      expect(page).to have_text(/Kapitalwert/i)
      expect(page).to have_text(/Nominaler Saldo heute/i)
      expect(page).to have_css('canvas')
    end

    it 'offers sliders to adjust the calculation parameters' do
      visit '/amortization'

      # Sliders live in a collapsible drawer, so open it first
      click_button 'Parameter anpassen'
      expect(page).to have_field('amortization[period_years]', type: 'range')
      expect(page).to have_field('amortization[interest_rate]', type: 'range')
    end

    it 'maximizes the chart to fullscreen and back' do
      visit '/amortization'

      # The minimize button only shows once the chart is maximized
      expect(page).to have_button('Maximal vergrößern')
      expect(page).to have_no_button('Zurück zur normalen Größe')

      click_button 'Maximal vergrößern'
      expect(page).to have_button('Zurück zur normalen Größe')

      click_button 'Zurück zur normalen Größe'
      expect(page).to have_button('Maximal vergrößern')
    end
  end
end
