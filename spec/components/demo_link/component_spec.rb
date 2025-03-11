describe DemoLink::Component, type: :component do
  subject(:component) { described_class.new(url:, feature:) }

  let(:url) { { controller: 'house/home', action: 'index' } }
  let(:feature) { 'custom_consumer' }

  it 'renders the buttons' do
    render_inline(component)

    expect(page).to have_link 'How to become a sponsor?',
              href: 'https://solectrus.de/sponsoring'

    expect(page).to have_link 'Demo', href: 'https://demo.solectrus.de/house'
  end
end
