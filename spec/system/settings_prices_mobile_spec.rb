describe 'Settings prices (mobile)' do
  before do
    driven_by :playwright_mobile
    login_as_admin
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
end
