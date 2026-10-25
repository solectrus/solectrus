describe Ui::EmptyState::Component, type: :component do
  it 'renders the icon, the title, the text and the content' do
    render_inline(described_class.new(icon: 'car', title: 'No drives', text: 'The car stood still.')) { 'More' }

    aggregate_failures do
      expect(page).to have_css('.fa-car', visible: :all)
      expect(page).to have_text('No drives')
      expect(page).to have_text('The car stood still.')
      expect(page).to have_text('More')
    end
  end

  it 'takes the small size for a chart' do
    render_inline(described_class.new(icon: 'chart-line', title: 'No data', size: :small))

    expect(page).to have_css('div.size-16')
  end
end
