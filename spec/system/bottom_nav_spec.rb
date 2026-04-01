describe 'Bottom navigation (mobile)' do
  before { driven_by :playwright_mobile }

  it 'navigates to another page via bottom bar' do
    visit '/'

    within('nav[aria-label="Main navigation"]') do
      click_on 'Erzeugung'
    end

    expect(page).to have_current_path(%r{/inverter_power/})
  end

  it 'toggles the "More" menu with extra and secondary items' do
    visit '/'

    # Open "More" menu
    within('nav[aria-label="Main navigation"]') do
      click_on 'Mehr'
    end

    # Extra items and secondary items should be visible
    expect(page).to have_link('Top 10')
    expect(page).to have_link('Einstellungen')

    # Close "More" menu
    within('nav[aria-label="Main navigation"]') do
      click_on 'Mehr'
    end

    # Dropdown should collapse
    expect(page).to have_css('[data-nav--bottom--component-target="dropdown"].h-0')
  end
end
