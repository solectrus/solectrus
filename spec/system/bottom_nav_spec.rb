describe 'Bottom navigation (mobile)' do
  before { driven_by :playwright_mobile }

  def tab_bar(&)
    within('nav[aria-label="Main navigation"]', &)
  end

  it 'navigates to another page via bottom bar' do
    visit '/'

    tab_bar { click_on 'Hausverbrauch' }

    expect(page).to have_current_path(%r{/house/house_power/})
  end

  # optimistic-nav moves the marking to the tapped item before the page it
  # points to arrives, and the page then brings the marking of the server. Both
  # have to end up on the same item, and on one item only.
  it 'marks exactly one item after a navigation' do
    visit '/'

    tab_bar do
      click_on 'Hausverbrauch'

      expect(page).to have_css('a[aria-current]', count: 1)
      expect(page).to have_css('a[aria-current][aria-label="Hausverbrauch"]')
    end
  end

  # A tool is a page below the page More. It slides in with a title bar, and
  # its back button slides back to the list.
  it 'slides from the page More to a tool and back' do
    visit '/'
    tab_bar { click_on 'Mehr' }
    expect(page).to have_css('.ui-title-bar h1 img[alt="Mehr"]')

    click_on 'Top 10'
    expect(page).to have_css('.ui-title-bar h1', text: 'Top 10')
    expect(page).to have_current_path(%r{/top10/})

    find('.ui-title-bar-back').click
    expect(page).to have_current_path('/more')
    tab_bar { expect(page).to have_css('a[aria-current][aria-label="Mehr"]') }
  end

  # A tab that does not fit into the tab bar stays a tab: it takes the
  # timeframe of the other tabs over and shows no title bar.
  it 'opens a tab of the page More in the timeframe of the last tab' do
    visit '/house/house_power/now'
    click_on 'Woche'
    expect(page).to have_current_path(%r{/house/house_power/\d{4}-W\d{2}})
    week = page.current_path.split('/').last

    tab_bar { click_on 'Mehr' }
    click_on 'Erzeugung'

    expect(page).to have_current_path("/inverter/inverter_power/#{week}")
    expect(page).to have_no_css('.ui-title-bar')
    tab_bar { expect(page).to have_css('a[aria-current][aria-label="Mehr"]') }
  end

  # The answer to the switch morphs the page, so it neither loads anew nor
  # jumps to the top. The switch stays where it was on the screen. A text
  # above it can take another number of lines in the other language, so the
  # browser can move the scroll position to keep the switch in place.
  it 'switches the language in place, at the scroll position of the page' do
    visit '/more'
    page.execute_script(<<~JS)
      window.notReloaded = true;
      document.querySelector('main').scrollTop = 200;
    JS
    switch_top = "Math.round(document.querySelector('form[action=\"/locale\"]').getBoundingClientRect().top)"
    top = page.evaluate_script(switch_top)

    click_on 'EN'

    expect(page).to have_css('html[lang="en"]', visible: :all)
    expect(page).to have_css('.ui-title-bar h1 img[alt="More"]')
    expect(page.evaluate_script('window.notReloaded')).to be(true)
    expect(page.evaluate_script(switch_top)).to eq(top)
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

    tab_bar { click_on 'Mehr' }
    expect(page).to have_link('Einstellungen')

    expect(page).to have_no_css('[data-fullscreen-btn]')
  end

  # Fullscreen is a mode of the document, which Turbo keeps from page to page.
  # So the page that the user opens next shows in fullscreen.
  it 'keeps fullscreen on the next page' do
    visit '/more'

    find('input[role="switch"][aria-label="Vollbild"]').click
    expect(page).to have_css('html:fullscreen', visible: :all)

    click_on 'Erzeugung'
    expect(page).to have_current_path(%r{/inverter/inverter_power/})
    expect(page).to have_css('html:fullscreen', visible: :all)
  end

  # A morph sets the switch back to the state the server rendered, so the
  # switch has to follow the mode again.
  it 'keeps the fullscreen switch on after a page refresh' do
    visit '/more'
    find('input[role="switch"][aria-label="Vollbild"]').click
    expect(page).to have_css('html:fullscreen', visible: :all)

    page.execute_script(<<~JS)
      addEventListener(
        'turbo:morph',
        () => document.body.setAttribute('data-morphed', ''),
        { once: true },
      );
      Turbo.visit(window.location.href, { action: 'replace' });
    JS
    expect(page).to have_css('body[data-morphed]', visible: :all)

    expect(page.evaluate_script("document.querySelector('input[role=\"switch\"]').checked")).to be(true)
  end
end
