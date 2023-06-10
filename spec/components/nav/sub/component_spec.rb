describe Nav::Sub::Component, type: :component do
  it 'renders menu' do
    items = [
      { name: 'one', href: '/one' },
      { name: 'two', href: '/two', current: true },
    ]

    expect(
      render_inline(described_class.new) do |component|
        component.with_items(items)
      end.css('a').to_html,
    ).to include('href="/one"', 'href="/two"')
  end
end
