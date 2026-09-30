describe Nav::List::Component, type: :component do
  let(:items) do
    [
      { name: 'General', href: '/general', icon: 'gear' },
      { name: 'Sensors', href: '/sensors', icon: 'sliders' },
    ]
  end

  it 'renders a row with name and link per section' do
    rows = render_inline(described_class.new(items:, label: 'Settings')).css('li a')

    expect(rows.map { |row| [row.text.strip, row['href']] }).to eq(
      [%w[General /general], %w[Sensors /sensors]],
    )
  end
end
