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

      # On desktop the sliders sit inline in the sub-navigation bar
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

      # On desktop the sliders sit inline in the sub-navigation bar
      expect(page).to have_field('amortization[period_years]', type: 'range')
      expect(page).to have_field('amortization[interest_rate]', type: 'range')
    end

    it 'navigates from the chart to the table and back' do
      visit '/amortization'

      # The chart is the default view; the table stays on its own URL
      expect(page).to have_css('canvas', visible: :visible)
      expect(page).to have_no_text('Zurückverdient')

      click_link 'Details'

      expect(page).to have_current_path('/amortization/details')
      aggregate_failures do
        expect(page).to have_text('Jahr')
        expect(page).to have_text('Ersparnis')
        # The seeded -5000 cash flow gets its own investment column
        expect(page).to have_text('Investition')
        expect(page).to have_text('Nominaler Saldo')
        expect(page).to have_text('Zurückverdient')
        # Rows are PV years, not calendar years, so any savings link carries an
        # explicit date range - never a bare /savings/<year>
        expect(page).to have_no_link(href: %r{/savings/\d{4}$})
      end

      # The year number reveals its exact PV-year date range on hover
      first('[data-controller="tooltip"]', text: '1').hover
      expect(page).to have_text(/\d{2}\.\d{2}\.\d{4} – \d{2}\.\d{2}\.\d{4}/)

      # Back to the chart tab reveals the canvas again
      click_link 'Verlauf'
      expect(page).to have_current_path('/amortization')
      expect(page).to have_css('canvas', visible: :visible)
    end

    it 'drills a cash-flow cell down to the filtered settings list' do
      visit '/amortization/details'

      # The seeded -5000 investment cell links to the settings list, filtered to
      # that category and the PV year - so the sum behind the cell is traceable.
      # The category filter is multi-select, so it rides along as category[]
      # (URL-encoded here) to match the checkbox form on the settings page.
      first("a[href*='/settings/cash_flows?category%5B%5D=investment']")
        .click

      aggregate_failures do
        expect(page).to have_current_path(
          %r{/settings/cash_flows},
          ignore_query: true,
        )
        expect(page).to have_text('Filter entfernen')
        expect(page).to have_text('PV system') # the seeded investment
      end
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
