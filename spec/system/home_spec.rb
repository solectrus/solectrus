describe 'Home', type: :system, js: true, vcr: true do
  it 'shows values' do
    visit '/'

    expect(page).to have_text('kWh', count: 4)
  end
end
