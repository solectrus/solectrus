describe SlideOver::Component, type: :component do
  before do
    render_inline(described_class.new)
  end

  it 'renders logo' do
    expect(page).to have_css('img[alt="SOLECTRUS"]')
  end

  it 'renders copyright info' do
    expect(page).to have_text(/© 2020–\d{4} Georg Ledermann · AGPL-3\.0/)
  end
end
