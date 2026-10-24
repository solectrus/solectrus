describe 'Settings prices (mobile)' do
  let!(:price) { Price.create!(name: :electricity, starts_at: Date.new(2024, 3, 1), amount_per_kwh: 0.3) }

  before do
    driven_by :playwright_mobile
    login_as_admin
  end

  # A system spec runs without a transaction
  after { Price.where(id: price.id).delete_all }

  # The form opens in a sheet over the list. A save closes the sheet and
  # refreshes the list, and the history keeps no entry of the form, so the
  # way back leads to the overview.
  it 'saves in a sheet over the list' do
    visit settings_path
    click_on 'Strompreis'
    expect(page).to have_current_path('/settings/prices/electricity')

    click_on I18n.l(price.starts_at, locale: :de)
    within('dialog#modal-sheet') do
      expect(page).to have_css('h2', text: 'Strompreis bearbeiten')
      fill_in 'price_note', with: 'New tariff'
      click_on 'Speichern'
    end

    expect(page).to have_no_css('dialog#modal-sheet[open]')
    expect(page).to have_current_path('/settings/prices/electricity')
    expect(page).to have_text('New tariff')

    page.go_back
    expect(page).to have_current_path('/settings')
  end

  # The back button goes back in the history, so the list becomes the entry
  # after the overview, as after the back button of the browser
  it 'goes back in the history with the back button' do
    visit settings_path
    click_on 'Strompreis'
    expect(page).to have_current_path('/settings/prices/electricity')

    find('.ui-title-bar-back').click
    expect(page).to have_current_path('/settings')

    page.go_forward
    expect(page).to have_current_path('/settings/prices/electricity')
  end

  # The first tap goes back at the end of the slide. A second tap during the
  # slide must not go back a second step.
  it 'goes back one step on a double tap of the back button' do
    page.driver.with_playwright_page { it.emulate_media(reducedMotion: 'no-preference') }
    visit more_path
    click_on 'Einstellungen'
    click_on 'Strompreis'
    expect(page).to have_current_path('/settings/prices/electricity')

    page.execute_script(<<~JS)
      const back = document.querySelector('.ui-title-bar-back');
      back.click();
      setTimeout(() => back.click(), 50);
    JS
    expect(page).to have_current_path('/settings')

    # A second step back would follow at the end of the slide
    sleep 1
    expect(page).to have_current_path('/settings')
  end
end
