describe Ui::Chips::Component, type: :component do
  before do
    render_inline(
      described_class.new(
        label: 'Car',
        replace: true,
        items: [
          { name: 'All cars', href: '/cars', current: false },
          { name: 'ZOE', href: '/cars/2', current: true, leading: '<svg></svg>'.html_safe },
        ],
      ),
    )
  end

  it 'renders a link for each chip and marks the current one' do
    aggregate_failures do
      expect(page).to have_css('nav[aria-label="Car"] a', count: 2)
      expect(page.find_link('ZOE', href: '/cars/2')['aria-current']).to eq('page')
      expect(page.find_link('All cars')['aria-current']).to be_nil
      expect(page).to have_css('a[href="/cars/2"] svg')
    end
  end

  it 'replaces the entry of the browser history' do
    expect(page.find_link('ZOE')['data-turbo-action']).to eq('replace')
  end
end
