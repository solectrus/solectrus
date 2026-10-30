describe Ui::SectionHeader::Component, type: :component do
  it 'renders the title with the spacing of the caller' do
    render_inline(described_class.new(title: 'Access for AI', class: 'mb-4'))

    expect(page).to have_css('h2.border-b.mb-4', text: 'Access for AI')
  end
end
