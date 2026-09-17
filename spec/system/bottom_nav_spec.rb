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

  # Safari on the iPhone has no Fullscreen API, so an item that offers
  # fullscreen there throws as soon as it is tapped.
  it 'offers no fullscreen item without the Fullscreen API' do
    visit '/'

    # Take the API away, then change the page with Turbo. Turbo keeps the
    # patched browser context, which a full page load would throw away.
    page.execute_script('delete Element.prototype.requestFullscreen')
    page.execute_script("Turbo.visit('/inverter_power/now')")
    expect(page).to have_current_path('/inverter_power/now')

    within('nav[aria-label="Main navigation"]') { click_on 'Mehr' }
    expect(page).to have_link('Einstellungen')

    expect(page).to have_no_css('[data-fullscreen-btn]')
  end

  # Which of the two fullscreen items shows comes from CSS, so a morph of the
  # page cannot bring the other one back.
  it 'keeps a single fullscreen item after a page refresh' do
    visit '/'

    page.execute_script(<<~JS)
      addEventListener(
        'turbo:morph',
        () => document.body.setAttribute('data-morphed', ''),
        { once: true },
      );
      Turbo.visit(window.location.href, { action: 'replace' });
    JS
    expect(page).to have_css('body[data-morphed]', visible: :all)

    within('nav[aria-label="Main navigation"]') { click_on 'Mehr' }

    expect(page).to have_css('[data-fullscreen-btn="on"]')
    expect(page).to have_no_css('[data-fullscreen-btn="off"]')
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
