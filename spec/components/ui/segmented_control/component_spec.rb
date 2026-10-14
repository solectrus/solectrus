describe Ui::SegmentedControl::Component, type: :component do
  before do
    render_inline(
      described_class.new(
        label: 'Kinds',
        items: [
          { name: 'Wallbox', href: '/wallbox', current: true },
          { name: 'Offsite', href: '/offsite', current: false },
        ],
      ),
    )
  end

  it 'renders a link for each segment and marks the current one' do
    aggregate_failures do
      expect(page).to have_css('nav[aria-label="Kinds"] a', count: 2)
      expect(page).to have_link('Wallbox', href: '/wallbox')
      expect(page.find_link('Wallbox')['aria-current']).to eq('page')
      expect(page.find_link('Offsite')['aria-current']).to be_nil
    end
  end
end
