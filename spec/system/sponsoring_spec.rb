describe 'Sponsoring page' do
  before do
    allow(UpdateCheck).to receive_messages(
      eligible_for_free?: false,
      sponsoring?: false,
    )

    visit '/sponsoring'
  end

  it 'opens the admin login page' do
    click_on 'Als Admin anmelden'

    expect(page).to have_current_path(new_session_path)
    expect(page).to have_css('#new_admin_user')
  end
end
