describe Ui::NavList::Component, type: :component do
  let(:items) do
    [
      { name: 'General', href: '/general', icon: 'gear' },
      { name: 'Sensors', href: '/sensors', icon: 'sliders' },
    ]
  end

  before { render_inline(described_class.new(items:, label: 'Settings')) }

  it 'renders a row with name and link per section' do
    rows = page.all('li a')

    expect(rows.map { |row| [row.text.strip, row['href']] }).to eq(
      [%w[General /general], %w[Sensors /sensors]],
    )
  end

  it 'lets each row slide one level down' do
    link = page.find('a[href="/general"]')

    aggregate_failures do
      expect(link['data-nav-title']).to eq('General')
      expect(link['data-turbo-prefetch']).to eq('false')
      expect(link).to have_css('.fa-chevron-right')
    end
  end
end
