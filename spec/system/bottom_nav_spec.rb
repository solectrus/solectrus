describe 'Bottom navigation (mobile)' do
  before { driven_by :playwright_mobile }

  it 'navigates to another page via bottom bar' do
    visit '/'

    within('nav[aria-label="Main navigation"]') do
      click_on 'Erzeugung'
    end

    expect(page).to have_current_path(%r{/inverter_power/})
  end

  # optimistic-nav moves the marking to the tapped item before the page it
  # points to arrives, and the page then brings the marking of the server. Both
  # have to end up on the same item, and on one item only.
  it 'marks exactly one item after a navigation' do
    visit '/'

    within('nav[aria-label="Main navigation"]') do
      click_on 'Erzeugung'

      expect(page).to have_css('a[aria-current]', count: 1)
      expect(page).to have_css('a[aria-current][aria-label="Erzeugung"]')
    end
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
