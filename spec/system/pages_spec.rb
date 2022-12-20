describe 'Pages', vcr: { cassette_name: 'version' } do
  it 'renders about page' do
    visit '/about'
    expect(page).to have_text('Über Solectrus')
  end
end
