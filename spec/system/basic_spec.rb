describe 'Basic functionality' do
  include ActiveSupport::Testing::TimeHelpers

  before { travel_to Time.zone.local(2022, 6, 21, 12, 0, 0) }

  it 'loads the home page correctly' do
    visit '/'

    expect(page).to have_current_path(%r{/(house_power|inverter_power)/now})

    expect(page).to have_content('SOLECTRUS.de')
    expect(page).to have_content('ledermann.dev')
    expect(page).to have_content('12:00')
  end
end
