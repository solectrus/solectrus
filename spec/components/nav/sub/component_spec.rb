describe Nav::Sub::Component, type: :component do
  it 'renders menu' do
    items = [{ name: 'one', href: '/one' }, { name: 'two', href: '/two' }]

    expect(
      render_inline(described_class.new) { |component| component.items(items) }
        .css('a')
        .to_html,
    ).to include('href="/one"', 'href="/two"')
  end
end
