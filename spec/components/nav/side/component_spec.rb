describe Nav::Side::Component, type: :component do
  let(:items) { [{ name: 'Cars', href: '/settings/cars' }, { name: 'Places', href: '/settings/places' }] }

  it 'shows the pages beside the content' do
    render_inline(described_class.new(items:)) { 'Content' }

    aggregate_failures do
      expect(page).to have_link('Places', href: '/settings/places')
      expect(page).to have_text('Content')
    end
  end

  it 'shows the content alone for a single page' do
    render_inline(described_class.new(items: items.first(1))) { 'Content' }

    aggregate_failures do
      expect(page).to have_no_css('nav')
      expect(page).to have_text('Content')
    end
  end
end
