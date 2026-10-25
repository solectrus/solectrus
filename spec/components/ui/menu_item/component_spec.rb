describe Ui::MenuItem::Component, type: :component do
  it 'renders a link that marks the current page' do
    render_inline(described_class.new(name: 'Day', href: '/day', current: true))

    expect(page).to have_css('a[href="/day"][aria-current="page"]', text: 'Day')
  end

  it 'opens a link to another site in a new tab' do
    render_inline(described_class.new(name: 'Docs', href: 'https://example.com'))

    expect(page).to have_css('a[target="_blank"]', text: 'Docs')
  end

  it 'renders a button without href, with the action of its data' do
    render_inline(described_class.new(name: 'Log out', data: { action: 'session#logout' }))

    expect(page).to have_css('button[data-action="session#logout"]', text: 'Log out')
  end

  it 'renders a line for the name "-"' do
    render_inline(described_class.new(name: '-'))

    expect(page).to have_css('hr', visible: :all)
  end

  it 'shows a badge with a positive count' do
    render_inline(described_class.new(name: 'News', href: '/news', badge_count: 3, badge_data: { notification_badge: true }))

    expect(page).to have_css('a span[data-notification-badge]', text: '3')
  end
end
