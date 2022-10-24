describe 'Pages' do
  it 'renders about page' do
    visit '/about'
    expect(page).to have_text('Über Solectrus')
  end
end
