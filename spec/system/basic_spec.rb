describe 'Basic functionality' do
  include ActiveSupport::Testing::TimeHelpers

  it 'loads the home page correctly' do
    visit '/'

    expect(page).to have_current_path('/power_balance/now')

    expect(page).to have_content('SOLECTRUS.de')
    expect(page).to have_content('ledermann.dev')
    expect(page).to have_content('12:00')
  end
end
