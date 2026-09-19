describe Nav::Sub::Component, type: :component do
  def render_nav(items)
    render_inline(described_class.new) { |component| component.with_items(items) }
  end

  it 'renders menu' do
    items = [
      { name: 'one', href: '/one' },
      { name: 'two', href: '/two', current: true },
    ]

    expect(render_nav(items).css('a').to_html).to include(
      'href="/one"',
      'href="/two"',
    )
  end

  context 'with a tab that carries a menu' do
    let(:menu) do
      [
        { name: 'by year', href: '/all' },
        { name: 'by month', href: '/all/by_month', current: true },
      ]
    end

    let(:current_tab) { render_nav([{ name: 'all', href: '/all', current: true, menu: }]) }
    let(:plain_tab) { render_nav([{ name: 'all', href: '/all', menu: }]) }

    it 'opens the menu from the current tab' do
      expect(current_tab.css('button').to_html).to include(
        'dropdown--component#toggle',
      )
      expect(current_tab.css('a').to_html).to include('href="/all/by_month"')
    end

    # The other tabs lead somewhere first, so there is nothing to open yet.
    it 'stays a link everywhere else' do
      expect(plain_tab.css('button')).to be_empty
      expect(plain_tab.css('a').to_html).not_to include('/all/by_month')
    end

    # The row has no width to spend on a mark, and a tab that grows the moment
    # it becomes the current one moves the whole row with it.
    it 'marks the menu without taking room in the row' do
      caret = current_tab.css('button > svg')

      expect(caret.size).to eq(1)
      expect(caret.attr('class').value).to include('absolute')
    end

    # A tab that only leads somewhere has nothing to open, so it says nothing.
    it 'marks the tab that can open its menu, and no other' do
      expect(plain_tab.css('svg')).to be_empty
    end

    it 'leaves a tab without readings unmarked' do
      html = render_nav([{ name: 'now', href: '/now' }])

      expect(html.css('svg')).to be_empty
    end
  end
end
